#!/usr/bin/env bash
# ==============================================================================
# Common node setup — runs ON an Ubuntu EC2 node (control plane or worker) as
# root, via SSM Run Command (preferred) or SSH (fallback). Installs
# containerd, kubeadm, kubelet, kubectl and required diagnostic tooling.
#
# Idempotent: safe to re-run. Does not use `set -x` (would risk echoing
# sensitive command substitutions into SSM/CloudWatch logs).
# ==============================================================================
set -Eeuo pipefail

# KUBERNETES_VERSION (e.g. "v1.35") is normally exported by whatever invokes
# this script (cluster-bootstrap.sh, sourcing cluster.env); this default only
# matters if the script is copied and run manually.
KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.35}"
KUBERNETES_INSTALL_VERSION="${KUBERNETES_VERSION#v}.*-*"
CONTAINERD_VERSION="${CONTAINERD_VERSION:-2.2.0}"
RUNC_VERSION="${RUNC_VERSION:-1.3.3}"
CRICTL_VERSION="${CRICTL_VERSION:-v1.35.0}"

log() { printf '[common.sh] %s\n' "$*"; }

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "common.sh must run as root" >&2
    exit 1
  fi
}
require_root

# ── Disable swap (immediately + persistently) ───────────────────────────────
log "Disabling swap"
swapoff -a
sed -i.bak -E 's/^([^#].*\sswap\s.*)$/# \1/' /etc/fstab
systemctl mask swap.target 2>/dev/null || true

# ── Kernel modules ───────────────────────────────────────────────────────────
log "Configuring kernel modules (overlay, br_netfilter)"
cat <<'EOF' > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# ── Sysctl: bridge netfilter + IPv4 forwarding (persist across reboots) ────
log "Configuring sysctl (bridge-nf, ip_forward)"
cat <<'EOF' > /etc/sysctl.d/99-ckne-kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null

# ── Base packages ────────────────────────────────────────────────────────────
log "Installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  apt-transport-https ca-certificates curl gpg software-properties-common \
  jq dnsutils tcpdump iproute2 iptables conntrack

# ── containerd + runc ────────────────────────────────────────────────────────
if ! command -v containerd >/dev/null 2>&1; then
  log "Installing containerd v${CONTAINERD_VERSION}"
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "${tmpdir}/containerd.tar.gz" \
    "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
  tar Cxzf /usr/local "${tmpdir}/containerd.tar.gz"
  rm -rf "$tmpdir"
else
  log "containerd already installed — skipping download"
fi

if ! command -v runc >/dev/null 2>&1; then
  log "Installing runc v${RUNC_VERSION}"
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "${tmpdir}/runc.amd64" \
    "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
  install -m 755 "${tmpdir}/runc.amd64" /usr/local/sbin/runc
  rm -rf "$tmpdir"
else
  log "runc already installed — skipping download"
fi

mkdir -p /etc/containerd
if [[ ! -f /etc/containerd/config.toml ]]; then
  containerd config default > /etc/containerd/config.toml
fi
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

if [[ ! -f /etc/systemd/system/containerd.service ]]; then
  cat <<'EOF' > /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable --now containerd
systemctl restart containerd
log "containerd active: $(systemctl is-active containerd)"

# ── crictl ───────────────────────────────────────────────────────────────────
if ! command -v crictl >/dev/null 2>&1; then
  log "Installing crictl ${CRICTL_VERSION}"
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "${tmpdir}/crictl.tar.gz" \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
  tar zxf "${tmpdir}/crictl.tar.gz" -C /usr/local/bin
  rm -rf "$tmpdir"
else
  log "crictl already installed — skipping download"
fi

cat <<'EOF' > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# ── kubeadm / kubelet / kubectl ──────────────────────────────────────────────
mkdir -p /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
  log "Adding Kubernetes apt repository (${KUBERNETES_VERSION})"
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key" \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
if ! command -v kubeadm >/dev/null 2>&1; then
  log "Installing kubelet/kubeadm/kubectl (${KUBERNETES_INSTALL_VERSION})"
  apt-get install -y --allow-change-held-packages kubelet kubeadm kubectl
else
  log "kubeadm already installed — skipping"
fi
apt-mark hold kubelet kubeadm kubectl

# ── kubelet node-ip (discovered dynamically via IMDSv2, no interface-name assumption) ──
log "Discovering private IP via IMDSv2"
IMDS_TOKEN="$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"
LOCAL_IP="$(curl -fsS -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
  "http://169.254.169.254/latest/meta-data/local-ipv4")"

if [[ -z "$LOCAL_IP" ]]; then
  echo "Failed to discover private IP via IMDSv2" >&2
  exit 1
fi
log "Private IP: ${LOCAL_IP}"

mkdir -p /etc/default
cat <<EOF > /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=${LOCAL_IP}
EOF

systemctl daemon-reload
systemctl enable kubelet

# ── Verification ─────────────────────────────────────────────────────────────
log "Verifying installation"
containerd --version
runc --version | { head -n1; cat >/dev/null; }
crictl --version
kubeadm version -o short
kubectl version --client -o yaml | grep gitVersion
log "common.sh completed successfully on $(hostname) (${LOCAL_IP})"
