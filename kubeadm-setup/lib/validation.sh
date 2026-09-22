#!/usr/bin/env bash
# Shared validation helpers. Source this file; do not execute it directly.
# Requires lib/logging.sh to already be sourced.

KUBEADM_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_ENV_FILE="${CLUSTER_ENV_FILE:-$KUBEADM_SETUP_DIR/config/cluster.env}"

REQUIRED_CLUSTER_ENV_VARS=(
  AWS_REGION
  AWS_AVAILABILITY_ZONE
  PROJECT_NAME
  RESOURCE_PREFIX
  TAG_PROJECT
  TAG_ENVIRONMENT
  TAG_MANAGED_BY
  TAG_RESOURCE_SET
  VPC_CIDR
  SUBNET_CIDR
  CONTROL_PLANE_NAME
  CONTROL_PLANE_INSTANCE_TYPE
  WORKER_NAME_PREFIX
  WORKER_INSTANCE_TYPE
  WORKER_COUNT
  ROOT_VOLUME_SIZE
  ROOT_VOLUME_TYPE
  KUBERNETES_VERSION
  POD_CIDR
  SERVICE_CIDR
)

require_cmd() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fatal "Missing required command(s): ${missing[*]}. Install them before continuing."
  fi
}

load_cluster_env() {
  if [[ ! -f "$CLUSTER_ENV_FILE" ]]; then
    log_fatal "Cluster config not found: $CLUSTER_ENV_FILE
  Create it first:
    cp kubeadm-setup/config/cluster.env.example kubeadm-setup/config/cluster.env
  then edit values as needed."
  fi
  set -a
  # shellcheck disable=SC1090
  source "$CLUSTER_ENV_FILE"
  set +a

  local missing=()
  for var in "${REQUIRED_CLUSTER_ENV_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fatal "cluster.env is missing required value(s): ${missing[*]}"
  fi

  if [[ "${ENABLE_SSH:-false}" == "true" && -z "${EC2_KEY_NAME:-}" ]]; then
    log_fatal "ENABLE_SSH=true requires EC2_KEY_NAME to be set to an existing EC2 key pair name."
  fi
}

verify_aws_identity() {
  require_cmd aws
  log_step "Verifying AWS credentials"
  local identity
  if ! identity=$(aws sts get-caller-identity --output json 2>/dev/null); then
    log_fatal "Unable to call 'aws sts get-caller-identity'. Check your AWS credentials/profile."
  fi
  local account
  account=$(printf '%s' "$identity" | jq -r '.Account')
  local arn
  arn=$(printf '%s' "$identity" | jq -r '.Arn')
  log_info "AWS account : $account"
  log_info "AWS caller  : $arn"
  log_info "AWS region  : ${AWS_REGION}"
}

confirm_prompt() {
  local prompt="$1"
  local reply
  read -r -p "$prompt [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}
