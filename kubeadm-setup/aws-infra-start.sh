#!/usr/bin/env bash
# Starts every project-tagged EC2 instance that is currently stopped, and
# waits for status checks + SSM registration before returning.
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

INSTANCE_IDS=( $(find_all_project_instances "stopped") )
if [[ ${#INSTANCE_IDS[@]} -eq 0 ]]; then
  log_info "No stopped project instances to start."
  exit 0
fi

log_step "Starting instances: ${INSTANCE_IDS[*]}"
aws ec2 start-instances --region "$AWS_REGION" --instance-ids "${INSTANCE_IDS[@]}" >/dev/null
wait_for_instances_running "${INSTANCE_IDS[@]}"
wait_for_status_checks "${INSTANCE_IDS[@]}"
for id in "${INSTANCE_IDS[@]}"; do
  wait_for_ssm_registration "$id"
done

log_ok "All instances running. Current addresses:"
"$SCRIPT_DIR/aws-infra-status.sh"

log_warn "If node private IPs changed, re-run: make cluster-bootstrap (safe/idempotent) so kubeadm config and kubelet node-ip reflect the new addresses."
