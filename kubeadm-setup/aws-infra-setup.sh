#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — AWS infrastructure create script
#
# Creates (only what is missing): VPC, public subnet, Internet Gateway, route
# table, security group, IAM role/instance profile for SSM, one control-plane
# EC2 instance and WORKER_COUNT worker EC2 instances. Idempotent — safe to
# run repeatedly. Never touches resources outside this project's tag set.
#
# Usage:
#   cp kubeadm-setup/config/cluster.env.example kubeadm-setup/config/cluster.env
#   # edit cluster.env
#   ./kubeadm-setup/aws-infra-setup.sh
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

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

log_step "Discovering Ubuntu 24.04 AMI via SSM public parameter"
AMI_ID="$(discover_ubuntu_ami_id)"
if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
  log_fatal "Could not discover an Ubuntu AMI ID via SSM in region $AWS_REGION"
fi
log_info "AMI: $AMI_ID"

ROOT_DEVICE_NAME="$(aws ec2 describe-images --region "$AWS_REGION" --image-ids "$AMI_ID" \
  --query 'Images[0].RootDeviceName' --output text)"

# ── VPC ──────────────────────────────────────────────────────────────────────
log_step "VPC"
VPC_ID="$(find_vpc_id)"
if [[ -z "$VPC_ID" ]]; then
  VPC_ID="$(aws ec2 create-vpc --region "$AWS_REGION" --cidr-block "$VPC_CIDR" \
    --tag-specifications "$(tag_spec vpc "${RESOURCE_PREFIX}-vpc")" \
    --query 'Vpc.VpcId' --output text)"
  aws ec2 modify-vpc-attribute --region "$AWS_REGION" --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
  aws ec2 modify-vpc-attribute --region "$AWS_REGION" --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
  log_ok "VPC created: $VPC_ID"
else
  log_info "VPC already exists: $VPC_ID"
fi

# ── Subnet ───────────────────────────────────────────────────────────────────
log_step "Public subnet"
SUBNET_ID="$(find_subnet_id "$VPC_ID")"
if [[ -z "$SUBNET_ID" ]]; then
  SUBNET_ID="$(aws ec2 create-subnet --region "$AWS_REGION" \
    --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR" --availability-zone "$AWS_AVAILABILITY_ZONE" \
    --tag-specifications "$(tag_spec subnet "${RESOURCE_PREFIX}-subnet")" \
    --query 'Subnet.SubnetId' --output text)"
  aws ec2 modify-subnet-attribute --region "$AWS_REGION" --subnet-id "$SUBNET_ID" --map-public-ip-on-launch
  log_ok "Subnet created: $SUBNET_ID"
else
  log_info "Subnet already exists: $SUBNET_ID"
fi

# ── Internet Gateway ─────────────────────────────────────────────────────────
log_step "Internet Gateway"
IGW_ID="$(find_igw_id "$VPC_ID")"
if [[ -z "$IGW_ID" ]]; then
  IGW_ID="$(aws ec2 create-internet-gateway --region "$AWS_REGION" \
    --tag-specifications "$(tag_spec internet-gateway "${RESOURCE_PREFIX}-igw")" \
    --query 'InternetGateway.InternetGatewayId' --output text)"
  aws ec2 attach-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
  log_ok "IGW created + attached: $IGW_ID"
else
  log_info "IGW already exists: $IGW_ID"
fi

# ── Route table ──────────────────────────────────────────────────────────────
log_step "Route table"
RT_ID="$(find_route_table_id "$VPC_ID")"
if [[ -z "$RT_ID" ]]; then
  RT_ID="$(aws ec2 create-route-table --region "$AWS_REGION" --vpc-id "$VPC_ID" \
    --tag-specifications "$(tag_spec route-table "${RESOURCE_PREFIX}-rt")" \
    --query 'RouteTable.RouteTableId' --output text)"
  aws ec2 create-route --region "$AWS_REGION" --route-table-id "$RT_ID" \
    --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
  aws ec2 associate-route-table --region "$AWS_REGION" --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID" >/dev/null
  log_ok "Route table created + associated: $RT_ID"
else
  log_info "Route table already exists: $RT_ID"
  ASSOC="$(aws ec2 describe-route-tables --region "$AWS_REGION" --route-table-ids "$RT_ID" \
    --query "RouteTables[0].Associations[?SubnetId=='${SUBNET_ID}'] | length(@)" --output text)"
  if [[ "$ASSOC" == "0" ]]; then
    aws ec2 associate-route-table --region "$AWS_REGION" --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID" >/dev/null
    log_info "Associated route table with subnet"
  fi
fi

# ── Security group ───────────────────────────────────────────────────────────
log_step "Security group"
if [[ "$ENABLE_SSH" == "true" && -z "$ALLOWED_ADMIN_CIDR" ]]; then
  log_fatal "ENABLE_SSH=true requires ALLOWED_ADMIN_CIDR to be set — refusing to open SSH to the world."
fi

SG_ID="$(find_sg_id "$VPC_ID")"
if [[ -z "$SG_ID" ]]; then
  SG_ID="$(aws ec2 create-security-group --region "$AWS_REGION" \
    --group-name "${RESOURCE_PREFIX}-sg" --description "CKNE hands-on lab cluster security group" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "$(tag_spec security-group "${RESOURCE_PREFIX}-sg")" \
    --query 'GroupId' --output text)"
  log_ok "Security group created: $SG_ID"
else
  log_info "Security group already exists: $SG_ID"
fi

# Remove any pre-existing unrestricted (0.0.0.0/0, all protocols) inbound rule.
UNRESTRICTED_RULE_IDS="$(aws ec2 describe-security-group-rules --region "$AWS_REGION" \
  --filters "Name=group-id,Values=${SG_ID}" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol=='-1' && CidrIpv4=='0.0.0.0/0'].SecurityGroupRuleId" \
  --output text)"
if [[ -n "$UNRESTRICTED_RULE_IDS" ]]; then
  log_warn "Revoking unrestricted inbound rule(s) found on ${SG_ID}: $UNRESTRICTED_RULE_IDS"
  # shellcheck disable=SC2086
  aws ec2 revoke-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" \
    --security-group-rule-ids $UNRESTRICTED_RULE_IDS
fi

authorize_ingress_if_missing() {
  # $1 = description (for logging), remaining = full authorize-security-group-ingress args
  local desc="$1"; shift
  if aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" "$@" >/dev/null 2>&1; then
    log_info "Added rule: $desc"
  else
    log_info "Rule already present: $desc"
  fi
}

# Node-to-node (incl. required Cilium overlay/health traffic) — all protocols within the SG itself.
authorize_ingress_if_missing "all traffic within cluster SG (node-to-node + Cilium)" \
  --ip-permissions "IpProtocol=-1,UserIdGroupPairs=[{GroupId=${SG_ID},Description='intra-cluster'}]"

# API server (6443) from the cluster SG (redundant with the rule above, kept explicit per design).
authorize_ingress_if_missing "tcp/6443 from cluster SG" \
  --ip-permissions "IpProtocol=tcp,FromPort=6443,ToPort=6443,UserIdGroupPairs=[{GroupId=${SG_ID},Description='api-server-intra-cluster'}]"

# NodePort range from the cluster SG.
authorize_ingress_if_missing "tcp/30000-32767 (NodePort) from cluster SG" \
  --ip-permissions "IpProtocol=tcp,FromPort=30000,ToPort=32767,UserIdGroupPairs=[{GroupId=${SG_ID},Description='nodeport-intra-cluster'}]"

if [[ -n "$ALLOWED_ADMIN_CIDR" ]]; then
  authorize_ingress_if_missing "tcp/6443 from ALLOWED_ADMIN_CIDR ($ALLOWED_ADMIN_CIDR)" \
    --ip-permissions "IpProtocol=tcp,FromPort=6443,ToPort=6443,IpRanges=[{CidrIp=${ALLOWED_ADMIN_CIDR},Description='admin-api-access'}]"
fi

if [[ -n "${ALLOWED_NODEPORT_CIDR:-}" ]]; then
  authorize_ingress_if_missing "tcp/30000-32767 from ALLOWED_NODEPORT_CIDR ($ALLOWED_NODEPORT_CIDR)" \
    --ip-permissions "IpProtocol=tcp,FromPort=30000,ToPort=32767,IpRanges=[{CidrIp=${ALLOWED_NODEPORT_CIDR},Description='admin-nodeport-access'}]"
fi

if [[ "$ENABLE_SSH" == "true" ]]; then
  authorize_ingress_if_missing "tcp/22 from ALLOWED_ADMIN_CIDR ($ALLOWED_ADMIN_CIDR)" \
    --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${ALLOWED_ADMIN_CIDR},Description='admin-ssh-access'}]"
else
  log_info "SSH disabled (ENABLE_SSH=false) — no port 22 rule added. Use SSM Session Manager for shell access."
fi

log_info "etcd (2379-2380), kubelet API (10250), controller-manager (10257) and scheduler (10259) are reachable"
log_info "only via the intra-cluster-SG rule above — never exposed to the internet."

# ── IAM role + instance profile for SSM ─────────────────────────────────────
log_step "IAM role + instance profile (SSM)"
ROLE_NAME="${RESOURCE_PREFIX}-ssm-role"
PROFILE_NAME="${RESOURCE_PREFIX}-ssm-profile"

if [[ -z "$(find_iam_role_name)" ]]; then
  TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --tags Key=Project,Value="$TAG_PROJECT" Key=Environment,Value="$TAG_ENVIRONMENT" \
           Key=ManagedBy,Value="$TAG_MANAGED_BY" Key=ResourceSet,Value="$TAG_RESOURCE_SET" >/dev/null
  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  log_ok "IAM role created: $ROLE_NAME"
else
  log_info "IAM role already exists: $ROLE_NAME"
fi

if [[ -z "$(find_instance_profile_name)" ]]; then
  aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME"
  log_ok "Instance profile created: $PROFILE_NAME"
  log_info "Waiting for IAM instance profile to propagate..."
  sleep 10
else
  log_info "Instance profile already exists: $PROFILE_NAME"
fi

# ── Launch instances ─────────────────────────────────────────────────────────
block_device_mapping() {
  printf 'DeviceName=%s,Ebs={VolumeSize=%s,VolumeType=%s,Encrypted=true,DeleteOnTermination=true}' \
    "$ROOT_DEVICE_NAME" "$ROOT_VOLUME_SIZE" "$ROOT_VOLUME_TYPE"
}

launch_instance_if_missing() {
  local name="$1" role="$2" instance_type="$3" extra_tag="$4"
  local existing
  existing="$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "${project_tag_filters[@]}" "Name=tag:Name,Values=${name}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null | sed 's/^None$//')"
  if [[ -n "$existing" ]]; then
    log_info "$name already exists: $existing"
    printf '%s' "$existing"
    return 0
  fi

  local run_instance_args=(
    --region "$AWS_REGION"
    --image-id "$AMI_ID"
    --instance-type "$instance_type"
    --subnet-id "$SUBNET_ID"
    --security-group-ids "$SG_ID"
    --associate-public-ip-address
    --iam-instance-profile "Name=${PROFILE_NAME}"
    --metadata-options "HttpTokens=required,HttpPutResponseHopLimit=2,HttpEndpoint=enabled"
    --block-device-mappings "$(block_device_mapping)"
    --count 1
    --query 'Instances[0].InstanceId'
    --output text
  )
  local tag_spec_str
  tag_spec_str="ResourceType=instance,Tags=[{Key=Name,Value=${name}},{Key=Project,Value=${TAG_PROJECT}},{Key=Environment,Value=${TAG_ENVIRONMENT}},{Key=ManagedBy,Value=${TAG_MANAGED_BY}},{Key=ResourceSet,Value=${TAG_RESOURCE_SET}},{Key=ckne:role,Value=${role}}${extra_tag}]"
  run_instance_args+=(--tag-specifications "$tag_spec_str")

  if [[ "$ENABLE_SSH" == "true" ]]; then
    run_instance_args+=(--key-name "$EC2_KEY_NAME")
  fi

  local id
  id="$(aws ec2 run-instances "${run_instance_args[@]}")"
  log_ok "$name launched: $id"
  printf '%s' "$id"
}

log_step "Control plane instance"
CP_ID="$(launch_instance_if_missing "$CONTROL_PLANE_NAME" "control-plane" "$CONTROL_PLANE_INSTANCE_TYPE" "")"

log_step "Worker instances (requested: $WORKER_COUNT)"
WORKER_IDS=()
for i in $(seq 1 "$WORKER_COUNT"); do
  wid="$(launch_instance_if_missing "${WORKER_NAME_PREFIX}-${i}" "worker" "$WORKER_INSTANCE_TYPE" ",{Key=ckne:index,Value=${i}}")"
  WORKER_IDS+=("$wid")
done

ALL_IDS=("$CP_ID" "${WORKER_IDS[@]:-}")

log_step "Waiting for instances to reach 'running'"
wait_for_instances_running "${ALL_IDS[@]}"

log_step "Waiting for EC2 status checks"
wait_for_status_checks "${ALL_IDS[@]}"

log_step "Waiting for SSM registration"
for id in "${ALL_IDS[@]}"; do
  wait_for_ssm_registration "$id"
done

log_step "Infrastructure ready"
printf '%-20s %-22s %-15s %-15s\n' "ROLE" "NAME" "INSTANCE ID" "PRIVATE IP"
printf '%-20s %-22s %-15s %-15s\n' "control-plane" "$CONTROL_PLANE_NAME" "$CP_ID" "$(instance_private_ip "$CP_ID")"
for i in "${!WORKER_IDS[@]:-}"; do
  idx=$((i + 1))
  wid="${WORKER_IDS[$i]}"
  printf '%-20s %-22s %-15s %-15s\n' "worker" "${WORKER_NAME_PREFIX}-${idx}" "$wid" "$(instance_private_ip "$wid")"
done

log_ok "Next: ./kubeadm-setup/cluster-bootstrap.sh"
