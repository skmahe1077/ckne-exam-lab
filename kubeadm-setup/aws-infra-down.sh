#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — AWS infrastructure destroy script
#
# Defaults to --dry-run: prints exactly what it would delete and does nothing.
# Pass --confirm to actually delete. Only ever touches resources carrying all
# four project tags (Project/Environment/ManagedBy/ResourceSet) discovered via
# lib/aws.sh — never the default VPC, never name-pattern matches.
#
# Usage:
#   ./kubeadm-setup/aws-infra-down.sh              # same as --dry-run
#   ./kubeadm-setup/aws-infra-down.sh --dry-run
#   ./kubeadm-setup/aws-infra-down.sh --confirm
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

MODE="dry-run"
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --confirm) MODE="confirm" ;;
    *) log_fatal "Unknown argument: $arg (expected --dry-run or --confirm)" ;;
  esac
done

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

log_step "Mode: $MODE"
if [[ "$MODE" == "dry-run" ]]; then
  log_info "DRY RUN — no resources will be deleted. Re-run with --confirm to actually delete."
fi

# ── Discover ──────────────────────────────────────────────────────────────────
log_step "Discovering project resources (tags: Project=$TAG_PROJECT Environment=$TAG_ENVIRONMENT ManagedBy=$TAG_MANAGED_BY ResourceSet=$TAG_RESOURCE_SET)"

INSTANCE_IDS=( $(find_all_project_instances) )
VPC_ID="$(find_vpc_id)"
SUBNET_ID=""
IGW_ID=""
RT_ID=""
SG_ID=""
if [[ -n "$VPC_ID" ]]; then
  SUBNET_ID="$(find_subnet_id "$VPC_ID")"
  IGW_ID="$(find_igw_id "$VPC_ID")"
  RT_ID="$(find_route_table_id "$VPC_ID")"
  SG_ID="$(find_sg_id "$VPC_ID")"
fi
ROLE_NAME="$(find_iam_role_name)"
PROFILE_NAME="$(find_instance_profile_name)"

echo ""
echo "The following resources belong to this project and would be deleted:"
echo "  EC2 instances       : ${INSTANCE_IDS[*]:-<none>}"
echo "  VPC                 : ${VPC_ID:-<none>}"
echo "  Subnet              : ${SUBNET_ID:-<none>}"
echo "  Internet Gateway    : ${IGW_ID:-<none>}"
echo "  Route table         : ${RT_ID:-<none>}"
echo "  Security group      : ${SG_ID:-<none>}"
echo "  IAM instance profile: ${PROFILE_NAME:-<none>}"
echo "  IAM role            : ${ROLE_NAME:-<none>}"
echo ""

if [[ -z "$VPC_ID" && ${#INSTANCE_IDS[@]} -eq 0 && -z "$ROLE_NAME" && -z "$PROFILE_NAME" ]]; then
  log_ok "Nothing found for this project — already clean."
  exit 0
fi

# Absolute safety net: never proceed against the account's default VPC.
if [[ -n "$VPC_ID" ]]; then
  IS_DEFAULT="$(aws ec2 describe-vpcs --region "$AWS_REGION" --vpc-ids "$VPC_ID" \
    --query 'Vpcs[0].IsDefault' --output text)"
  if [[ "$IS_DEFAULT" == "True" ]]; then
    log_fatal "Refusing to continue: the discovered VPC ($VPC_ID) is the account default VPC. This should never happen for a project-tagged VPC — investigate manually."
  fi
fi

if [[ "$MODE" == "dry-run" ]]; then
  log_info "Dry run complete. Re-run with --confirm to delete the resources listed above."
  exit 0
fi

if ! confirm_prompt "Delete ALL resources listed above in $AWS_REGION?"; then
  log_info "Aborted by user."
  exit 1
fi

# ── 1. EC2 instances ─────────────────────────────────────────────────────────
log_step "1/12 Terminating EC2 instances"
if [[ ${#INSTANCE_IDS[@]} -gt 0 ]]; then
  aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids "${INSTANCE_IDS[@]}" >/dev/null
  wait_for_instances_terminated "${INSTANCE_IDS[@]}"
  log_ok "Instances terminated."
else
  log_info "No instances to terminate."
fi

if [[ -z "$VPC_ID" ]]; then
  log_ok "No project VPC found — nothing further to clean up in networking."
else
  # ── 2. Project network interfaces (any leftover ENIs, e.g. from SSM/VPC endpoints) ──
  log_step "2/12 Deleting leftover project network interfaces"
  ENI_IDS=( $(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NetworkInterfaces[].NetworkInterfaceId' --output text) )
  for eni in "${ENI_IDS[@]:-}"; do
    [[ -z "$eni" ]] && continue
    aws ec2 delete-network-interface --region "$AWS_REGION" --network-interface-id "$eni" 2>/dev/null \
      && log_ok "Deleted ENI: $eni" \
      || log_warn "Could not delete ENI $eni yet (may still be detaching) — re-run if it persists."
  done

  # ── 3. Security group ─────────────────────────────────────────────────────
  log_step "3/12 Deleting security group"
  if [[ -n "$SG_ID" ]]; then
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$SG_ID"
    log_ok "Security group deleted: $SG_ID"
  else
    log_info "No security group found."
  fi

  # ── 4. Route-table associations / 5. non-main route table ────────────────
  log_step "4/12 Removing route-table associations"
  if [[ -n "$RT_ID" ]]; then
    ASSOC_IDS=( $(aws ec2 describe-route-tables --region "$AWS_REGION" --route-table-ids "$RT_ID" \
      --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' --output text) )
    for assoc in "${ASSOC_IDS[@]:-}"; do
      [[ -z "$assoc" ]] && continue
      aws ec2 disassociate-route-table --region "$AWS_REGION" --association-id "$assoc"
      log_ok "Disassociated: $assoc"
    done

    log_step "5/12 Deleting route table"
    aws ec2 delete-route-table --region "$AWS_REGION" --route-table-id "$RT_ID"
    log_ok "Route table deleted: $RT_ID"
  else
    log_info "No project route table found — skipping steps 4-5."
  fi

  # ── 6. Detach IGW / 7. delete IGW ─────────────────────────────────────────
  log_step "6/12 Detaching Internet Gateway"
  if [[ -n "$IGW_ID" ]]; then
    aws ec2 detach-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
    log_ok "IGW detached: $IGW_ID"

    log_step "7/12 Deleting Internet Gateway"
    aws ec2 delete-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW_ID"
    log_ok "IGW deleted: $IGW_ID"
  else
    log_info "No project IGW found — skipping steps 6-7."
  fi

  # ── 8. Subnet ──────────────────────────────────────────────────────────────
  log_step "8/12 Deleting subnet"
  if [[ -n "$SUBNET_ID" ]]; then
    aws ec2 delete-subnet --region "$AWS_REGION" --subnet-id "$SUBNET_ID"
    log_ok "Subnet deleted: $SUBNET_ID"
  else
    log_info "No project subnet found."
  fi
fi

# ── 9. IAM instance profile / 10. role attachments / 11. role ───────────────
log_step "9/12 Deleting IAM instance profile"
ROLE_NAME_FOR_PROFILE="${RESOURCE_PREFIX}-ssm-role"
if [[ -n "$PROFILE_NAME" ]]; then
  aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE_NAME" \
    --role-name "$ROLE_NAME_FOR_PROFILE" 2>/dev/null || true
  aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME"
  log_ok "Instance profile deleted: $PROFILE_NAME"
else
  log_info "No project instance profile found."
fi

log_step "10/12 Detaching IAM role policies"
if [[ -n "$ROLE_NAME" ]]; then
  aws iam detach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true
  log_ok "Policies detached from: $ROLE_NAME"

  log_step "11/12 Deleting IAM role"
  aws iam delete-role --role-name "$ROLE_NAME"
  log_ok "IAM role deleted: $ROLE_NAME"
else
  log_info "No project IAM role found — skipping steps 10-11."
fi

# ── 12. VPC ───────────────────────────────────────────────────────────────────
log_step "12/12 Deleting VPC"
if [[ -n "$VPC_ID" ]]; then
  aws ec2 delete-vpc --region "$AWS_REGION" --vpc-id "$VPC_ID"
  log_ok "VPC deleted: $VPC_ID"
else
  log_info "No project VPC found."
fi

log_ok "All project infrastructure destroyed."
