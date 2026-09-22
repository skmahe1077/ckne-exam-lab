#!/usr/bin/env bash
# Prints the status of every project-tagged EC2 instance (and whether SSM
# considers each node online). Read-only — never modifies anything.
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

log_step "Project instances"

INSTANCE_IDS=( $(find_all_project_instances "pending,running,stopping,stopped") )
if [[ ${#INSTANCE_IDS[@]} -eq 0 ]]; then
  log_info "No project instances found in $AWS_REGION. Run: make aws-create"
  exit 0
fi

printf '%-22s %-20s %-11s %-15s %-15s %-8s\n' "NAME" "INSTANCE ID" "STATE" "PRIVATE IP" "PUBLIC IP" "SSM"
for id in "${INSTANCE_IDS[@]}"; do
  info="$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$id" \
    --query 'Reservations[0].Instances[0].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,Priv:PrivateIpAddress,Pub:PublicIpAddress}' \
    --output json)"
  name="$(jq -r '.Name' <<<"$info")"
  state="$(jq -r '.State' <<<"$info")"
  priv="$(jq -r '.Priv // "-"' <<<"$info")"
  pub="$(jq -r '.Pub // "-"' <<<"$info")"
  ssm="$(aws ssm describe-instance-information --region "$AWS_REGION" \
    --filters "Key=InstanceIds,Values=${id}" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)"
  [[ "$ssm" == "None" || -z "$ssm" ]] && ssm="Offline"
  printf '%-22s %-20s %-11s %-15s %-15s %-8s\n' "$name" "$id" "$state" "$priv" "$pub" "$ssm"
done
