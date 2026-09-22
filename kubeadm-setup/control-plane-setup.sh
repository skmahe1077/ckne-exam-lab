#!/usr/bin/env bash
# ==============================================================================
# Control-plane node setup — runs ON the control-plane EC2 instance as root.
#
# Contract (set up by whatever invokes this script — normally
# cluster-bootstrap.sh, which concatenates a small header before this file's
# contents into a single SSM Run Command so both execute in the same shell):
#   - NODE_NAME is exported (hostname to assign to this node)
#   - A rendered kubeadm config (from config/kubeadm.config.template) already
#     exists at /tmp/ckne/kubeadm.config
#
# Idempotent: if the control plane is already initialized
# (/etc/kubernetes/admin.conf exists), this script only re-prints kubeconfig
# status and exits 0 rather than re-running kubeadm init.
# ==============================================================================
set -Eeuo pipefail

log() { printf '[control-plane-setup] %s\n' "$*"; }

if [[ "$(id -u)" -ne 0 ]]; then
  echo "control-plane-setup.sh must run as root" >&2
  exit 1
fi

: "${NODE_NAME:?NODE_NAME must be exported before running control-plane-setup.sh}"
KUBEADM_CONFIG="/tmp/ckne/kubeadm.config"
if [[ ! -f "$KUBEADM_CONFIG" ]]; then
  echo "Expected rendered kubeadm config at $KUBEADM_CONFIG — not found" >&2
  exit 1
fi

CURRENT_HOSTNAME="$(hostname)"
if [[ "$CURRENT_HOSTNAME" != "$NODE_NAME" ]]; then
  log "Setting hostname: $NODE_NAME"
  hostnamectl set-hostname "$NODE_NAME"
fi

if [[ -f /etc/kubernetes/admin.conf ]]; then
  log "Control plane already initialized — skipping kubeadm init."
else
  log "Running kubeadm init"
  mkdir -p /var/log/kubernetes
  kubeadm init --config="$KUBEADM_CONFIG" --upload-certs
fi

for home_dir in /root /home/ubuntu; do
  [[ -d "$home_dir" ]] || continue
  owner="root"
  [[ "$home_dir" == "/home/ubuntu" ]] && owner="ubuntu"
  mkdir -p "${home_dir}/.kube"
  cp -f /etc/kubernetes/admin.conf "${home_dir}/.kube/config"
  chown -R "${owner}:${owner}" "${home_dir}/.kube"
done

log "kubectl configured for root and ubuntu"
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide || true
log "control-plane-setup.sh completed on $(hostname)"
