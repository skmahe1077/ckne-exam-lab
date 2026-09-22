#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — full Kubernetes cluster reset
#
# Runs `kubeadm reset` on every project node and clears local Kubernetes
# state, WITHOUT touching the underlying EC2 instances (use aws-infra-down.sh
# for that). Use this to get a clean cluster after breaking something at the
# cluster level, without waiting for new EC2 instances to boot.
#
# This is destructive to cluster state — it asks for confirmation unless
# --yes is passed.
# ==============================================================================
set -Eeuo pipefail
export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"
# shellcheck source=lib/aws.sh
source "$SCRIPT_DIR/lib/aws.sh"
# shellcheck source=lib/kubernetes.sh
source "$SCRIPT_DIR/lib/kubernetes.sh"

AUTO_YES="false"
for arg in "$@"; do
  [[ "$arg" == "--yes" ]] && AUTO_YES="true"
done

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

CP_ID="$(find_instances_by_role control-plane | head -n1)"
WORKER_IDS=( $(find_instances_by_role worker) )
[[ -z "$CP_ID" ]] && log_fatal "No control-plane instance found."

log_warn "This will run 'kubeadm reset' on ALL cluster nodes (control plane + ${#WORKER_IDS[@]} worker(s)),"
log_warn "destroying every namespace, Pod, and cluster-level lab lock. EC2 instances themselves are kept."
if [[ "$AUTO_YES" != "true" ]]; then
  confirm_prompt "Reset the Kubernetes cluster on all nodes?" || { log_info "Aborted."; exit 1; }
fi

RESET_SCRIPT="$(mktemp)"
cat <<'EOF' > "$RESET_SCRIPT"
set -Eeuo pipefail
kubeadm reset -f --cri-socket unix:///run/containerd/containerd.sock || true
rm -rf /etc/cni/net.d
rm -rf "$HOME/.kube" /root/.kube /home/ubuntu/.kube
iptables -F || true
iptables -t nat -F || true
iptables -t mangle -F || true
iptables -X || true
echo "kubeadm reset complete on $(hostname)"
EOF

log_step "Resetting control plane: $CP_ID"
remote_run "$CP_ID" "$RESET_SCRIPT" "cluster-reset-cp"

for wid in "${WORKER_IDS[@]:-}"; do
  [[ -z "$wid" ]] && continue
  log_step "Resetting worker: $wid"
  remote_run "$wid" "$RESET_SCRIPT" "cluster-reset-worker"
done
rm -f "$RESET_SCRIPT"

log_ok "Cluster reset complete on all nodes."
log_info "Next: ./kubeadm-setup/cluster-bootstrap.sh"
