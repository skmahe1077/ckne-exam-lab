#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — download kubeconfig for local kubectl access
#
# Fetches /etc/kubernetes/admin.conf from the control plane via SSM Run
# Command (never SCP/SSH) and writes it locally. The file is git-ignored
# (kubeconfig* pattern) — never commit it.
#
# If ALLOWED_ADMIN_CIDR is set (6443 reachable from your IP), the server URL
# is rewritten to the control plane's public IP so kubectl works directly
# from your laptop. Otherwise the kubeconfig keeps the private IP and you
# must reach it through an SSM port-forwarding session:
#   aws ssm start-session --target <cp-instance-id> \
#     --document-name AWS-StartPortForwardingSession \
#     --parameters '{"portNumber":["6443"],"localPortNumber":["6443"]}'
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

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

CP_ID="$(find_instances_by_role control-plane | head -n1)"
[[ -z "$CP_ID" ]] && log_fatal "No control-plane instance found."

OUT_PATH="${1:-$SCRIPT_DIR/ckne-cluster.kubeconfig}"

log_step "Fetching kubeconfig from control plane ${CP_ID} via SSM"
KUBECONFIG_CONTENT="$(remote_run "$CP_ID" <(printf 'cat /etc/kubernetes/admin.conf\n') "fetch-kubeconfig")"

if [[ -z "$KUBECONFIG_CONTENT" ]]; then
  log_fatal "Received empty kubeconfig — is the cluster bootstrapped? Run cluster-bootstrap.sh first."
fi

printf '%s\n' "$KUBECONFIG_CONTENT" > "$OUT_PATH"
chmod 600 "$OUT_PATH"

if [[ -n "$ALLOWED_ADMIN_CIDR" ]]; then
  CP_PUBLIC_IP="$(instance_public_ip "$CP_ID")"
  if [[ -n "$CP_PUBLIC_IP" ]]; then
    sed -i.bak "s#server: https://[0-9.]*:6443#server: https://${CP_PUBLIC_IP}:6443#" "$OUT_PATH"
    rm -f "${OUT_PATH}.bak"
    log_ok "kubeconfig rewritten to use public endpoint: https://${CP_PUBLIC_IP}:6443"
  fi
else
  log_warn "ALLOWED_ADMIN_CIDR is not set — kubeconfig keeps the private control-plane IP."
  log_warn "Reach it via an SSM port-forwarding session (see this script's header comment) or set"
  log_warn "ALLOWED_ADMIN_CIDR in cluster.env, re-run aws-infra-setup.sh, and download again."
fi

log_ok "kubeconfig written to: $OUT_PATH (permissions 600, git-ignored)"
log_info "Use it with:  export KUBECONFIG=$OUT_PATH && kubectl get nodes"
