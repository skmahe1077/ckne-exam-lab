#!/usr/bin/env bash
# Shared AWS discovery/creation helpers. Source this file; do not execute it
# directly. Requires lib/logging.sh and lib/validation.sh (cluster.env
# already loaded) to be sourced first.
#
# Design rule: every "find_*" function filters on ALL FOUR project tags
# (Project/Environment/ManagedBy/ResourceSet) — never on Name alone — so
# that teardown/status scripts can never touch a resource that merely
# happens to share a name with something in this project.

aws_region_args() {
  printf -- '--region %s' "$AWS_REGION"
}

# Returns the --filters arguments (as an array via nameref) that match every
# resource this project owns.
project_tag_filters=(
  "Name=tag:Project,Values=${TAG_PROJECT:-}"
  "Name=tag:Environment,Values=${TAG_ENVIRONMENT:-}"
  "Name=tag:ManagedBy,Values=${TAG_MANAGED_BY:-}"
  "Name=tag:ResourceSet,Values=${TAG_RESOURCE_SET:-}"
)

# Must be called AFTER cluster.env is loaded (project_tag_filters above is
# evaluated at source time with possibly-empty values otherwise).
refresh_project_tag_filters() {
  project_tag_filters=(
    "Name=tag:Project,Values=${TAG_PROJECT}"
    "Name=tag:Environment,Values=${TAG_ENVIRONMENT}"
    "Name=tag:ManagedBy,Values=${TAG_MANAGED_BY}"
    "Name=tag:ResourceSet,Values=${TAG_RESOURCE_SET}"
  )
}

project_tags_kv() {
  # Emits Key=Value pairs (space separated) suitable for `aws ec2 create-tags --tags`
  printf 'Key=Project,Value=%s Key=Environment,Value=%s Key=ManagedBy,Value=%s Key=ResourceSet,Value=%s' \
    "$TAG_PROJECT" "$TAG_ENVIRONMENT" "$TAG_MANAGED_BY" "$TAG_RESOURCE_SET"
}

# tag_resource <resource-id> <Name value>
tag_resource() {
  local resource_id="$1" name_value="$2"
  # shellcheck disable=SC2086
  aws ec2 create-tags --region "$AWS_REGION" \
    --resources "$resource_id" \
    --tags Key=Name,Value="$name_value" $(project_tags_kv)
}

# tag_spec <resource-type> <Name value>
# Emits a --tag-specifications value usable inline on create-* calls that
# support it (run-instances, create-vpc, create-subnet, create-security-group, ...)
tag_spec() {
  local resource_type="$1" name_value="$2"
  printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=Project,Value=%s},{Key=Environment,Value=%s},{Key=ManagedBy,Value=%s},{Key=ResourceSet,Value=%s}]' \
    "$resource_type" "$name_value" "$TAG_PROJECT" "$TAG_ENVIRONMENT" "$TAG_MANAGED_BY" "$TAG_RESOURCE_SET"
}

find_vpc_id() {
  aws ec2 describe-vpcs --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=tag:Name,Values=${RESOURCE_PREFIX}-vpc" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null | sed 's/^None$//'
}

find_subnet_id() {
  local vpc_id="$1"
  aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=tag:Name,Values=${RESOURCE_PREFIX}-subnet" "Name=vpc-id,Values=${vpc_id}" \
    --query 'Subnets[0].SubnetId' --output text 2>/dev/null | sed 's/^None$//'
}

find_igw_id() {
  local vpc_id="$1"
  aws ec2 describe-internet-gateways --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=attachment.vpc-id,Values=${vpc_id}" \
    --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null | sed 's/^None$//'
}

find_route_table_id() {
  local vpc_id="$1"
  aws ec2 describe-route-tables --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=vpc-id,Values=${vpc_id}" \
    --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null | sed 's/^None$//'
}

find_sg_id() {
  local vpc_id="$1"
  aws ec2 describe-security-groups --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=tag:Name,Values=${RESOURCE_PREFIX}-sg" "Name=vpc-id,Values=${vpc_id}" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null | sed 's/^None$//'
}

find_iam_role_name() {
  local role_name="${RESOURCE_PREFIX}-ssm-role"
  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    printf '%s' "$role_name"
  fi
}

find_instance_profile_name() {
  local profile_name="${RESOURCE_PREFIX}-ssm-profile"
  if aws iam get-instance-profile --instance-profile-name "$profile_name" >/dev/null 2>&1; then
    printf '%s' "$profile_name"
  fi
}

# find_instances_by_role control-plane|worker  -> prints one instance-id per line
find_instances_by_role() {
  local role="$1"
  aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=tag:ckne:role,Values=${role}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d'
}

# find_all_project_instances [state-filter-csv, default running,pending,stopping,stopped]
find_all_project_instances() {
  local states="${1:-pending,running,stopping,stopped}"
  aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=instance-state-name,Values=${states}" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d'
}

discover_ubuntu_ami_id() {
  # Ubuntu 24.04 LTS (Noble), amd64, via the official Canonical SSM parameter
  # published to every commercial AWS region. No AMI ID is ever hard-coded.
  local param="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
  aws ssm get-parameter --region "$AWS_REGION" --name "$param" \
    --query 'Parameter.Value' --output text
}

wait_for_status_checks() {
  local instance_ids=("$@")
  [[ ${#instance_ids[@]} -eq 0 ]] && return 0
  log_info "Waiting for EC2 status checks (instance reachability) on: ${instance_ids[*]}"
  aws ec2 wait instance-status-ok --region "$AWS_REGION" --instance-ids "${instance_ids[@]}"
}

wait_for_instances_running() {
  local instance_ids=("$@")
  [[ ${#instance_ids[@]} -eq 0 ]] && return 0
  aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "${instance_ids[@]}"
}

wait_for_instances_terminated() {
  local instance_ids=("$@")
  [[ ${#instance_ids[@]} -eq 0 ]] && return 0
  log_info "Waiting for termination of: ${instance_ids[*]}"
  aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids "${instance_ids[@]}"
}

# wait_for_ssm_registration <instance-id> [timeout-seconds]
wait_for_ssm_registration() {
  local instance_id="$1" timeout="${2:-300}" elapsed=0
  log_info "Waiting for SSM registration: $instance_id"
  while (( elapsed < timeout )); do
    local status
    status=$(aws ssm describe-instance-information --region "$AWS_REGION" \
      --filters "Key=InstanceIds,Values=${instance_id}" \
      --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "None")
    if [[ "$status" == "Online" ]]; then
      log_ok "SSM online: $instance_id"
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  log_fatal "Timed out waiting for SSM registration on $instance_id after ${timeout}s"
}

instance_private_ip() {
  aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text
}

instance_public_ip() {
  aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null | sed 's/^None$//'
}

instance_name_tag() {
  aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value | [0]' --output text
}
