#!/usr/bin/env bash
# Stops (does not terminate) every project-tagged EC2 instance that is
# currently running, to save cost between practice sessions.
set -Eeuo pipefail
export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"
# shellcheck source=lib/aws.sh
source "$SCRIPT_DIR/lib/aws.sh"

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

INSTANCE_IDS=( $(find_all_project_instances "running") )
if [[ ${#INSTANCE_IDS[@]} -eq 0 ]]; then
  log_info "No running project instances to stop."
  exit 0
fi

log_step "Stopping instances: ${INSTANCE_IDS[*]}"
aws ec2 stop-instances --region "$AWS_REGION" --instance-ids "${INSTANCE_IDS[@]}" >/dev/null
aws ec2 wait instance-stopped --region "$AWS_REGION" --instance-ids "${INSTANCE_IDS[@]}"
log_ok "Stopped: ${INSTANCE_IDS[*]}"
log_warn "Public/private IPs will change on next start — re-run cluster-bootstrap.sh's discovery step, or download-kubeconfig.sh, after starting again."
