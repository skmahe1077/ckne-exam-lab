#!/usr/bin/env bash
# Shared Kubernetes bootstrap helpers (SSM command execution, kubeadm config
# rendering). Source this file; do not execute it directly. Requires
# lib/logging.sh, lib/validation.sh and lib/aws.sh to already be sourced.
#
# SSM Run Command is the default and preferred execution path (no SSH key,
# no open port 22, full audit trail in AWS). SSH is only used when a caller
# explicitly opts in via ENABLE_SSH=true, as a fallback.

# ssm_run <instance-id> <local-script-path> [comment]
# Uploads a local script to the instance via SSM Run Command (AWS-RunShellScript),
# executes it with bash, streams the terminal status, and returns the remote
# exit code. Never prints secrets: relies on the script itself not to echo any.
ssm_run() {
  local instance_id="$1" script_path="$2"
  local comment="${3:-$(basename "$script_path")}"
  require_cmd jq

  local params_file
  params_file="$(mktemp)"
  trap '[[ -n "${params_file:-}" ]] && rm -f "$params_file"' RETURN

  jq -n --rawfile script "$script_path" \
    '{commands: ($script | split("\n"))}' > "$params_file"

  local command_id
  command_id=$(aws ssm send-command --region "$AWS_REGION" \
    --instance-ids "$instance_id" \
    --document-name "AWS-RunShellScript" \
    --comment "$comment" \
    --timeout-seconds 1800 \
    --parameters "file://${params_file}" \
    --query 'Command.CommandId' --output text)

  # NOTE: all status/log lines in this function are written to stderr (>&2)
  # on purpose — callers routinely do `out=$(ssm_run ...)` to capture just
  # the remote command's own stdout (e.g. a join command, a version string).
  log_info "SSM command $command_id dispatched to $instance_id ($comment)" >&2

  local status="InProgress" elapsed=0 timeout=1800
  while [[ "$status" == "InProgress" || "$status" == "Pending" ]]; do
    sleep 5
    elapsed=$((elapsed + 5))
    status=$(aws ssm get-command-invocation --region "$AWS_REGION" \
      --command-id "$command_id" --instance-id "$instance_id" \
      --query 'Status' --output text 2>/dev/null || echo "Pending")
    if (( elapsed >= timeout )); then
      log_error "Timed out waiting for SSM command $command_id on $instance_id" >&2
      return 1
    fi
  done

  local invocation
  invocation=$(aws ssm get-command-invocation --region "$AWS_REGION" \
    --command-id "$command_id" --instance-id "$instance_id")
  printf '%s\n' "$invocation" | jq -r '.StandardOutputContent'

  if [[ "$status" != "Success" ]]; then
    log_error "SSM command failed on $instance_id (status: $status)" >&2
    printf '%s\n' "$invocation" | jq -r '.StandardErrorContent' >&2
    return 1
  fi
  log_ok "SSM command completed on $instance_id" >&2
}

# ssm_run_inline <instance-id> <single-command-string> [comment]
ssm_run_inline() {
  local instance_id="$1" cmd="$2" comment="${3:-inline-command}"
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$cmd" > "$tmp"
  ssm_run "$instance_id" "$tmp" "$comment"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# ssm_run_with_env <instance-id> <body-script-path> <comment> [NAME VALUE]...
# Builds a temp script that exports the given NAME=VALUE pairs (safely quoted)
# and then appends body-script's contents, so both run in the same remote
# shell/SSM command. Use this to pass per-node values (NODE_NAME, JOIN_COMMAND,
# ...) into worker-setup.sh / control-plane-setup.sh without relying on state
# left behind by an earlier, separate SSM command.
ssm_run_with_env() {
  local instance_id="$1" body_script="$2" comment="$3"
  shift 3
  local combined
  combined="$(mktemp)"
  {
    while (( "$#" >= 2 )); do
      printf 'export %s=%q\n' "$1" "$2"
      shift 2
    done
    cat "$body_script"
  } > "$combined"
  remote_run "$instance_id" "$combined" "$comment"
  local rc=$?
  rm -f "$combined"
  return $rc
}

# ssm_write_file <instance-id> <remote-path> <local-content-path> [comment]
# Writes local-content-path's contents to remote-path on the instance via a
# quoted heredoc (no interpretation of $ or backticks in the content).
ssm_write_file() {
  local instance_id="$1" remote_path="$2" local_content="$3"
  local comment="${4:-write-file:$remote_path}"
  local script
  script="$(mktemp)"
  {
    printf 'mkdir -p %q\n' "$(dirname "$remote_path")"
    printf "cat <<'CKNE_FILE_EOF' > %q\n" "$remote_path"
    cat "$local_content"
    printf '\nCKNE_FILE_EOF\n'
  } > "$script"
  remote_run "$instance_id" "$script" "$comment"
  local rc=$?
  rm -f "$script"
  return $rc
}

# ssh_run <instance-id> <local-script-path>
# SSH fallback transport, used only when ENABLE_SSH=true and SSM registration
# did not succeed (see remote_run/CKNE_TRANSPORT below). Requires the
# instance's public IP and EC2_KEY_NAME's private key at ~/.ssh/<name>.pem
# (or SSH_KEY_PATH if set) to be available locally — this repository never
# stores that key.
ssh_run() {
  local instance_id="$1" script_path="$2"
  require_cmd ssh
  local ip
  ip="$(instance_public_ip "$instance_id")"
  if [[ -z "$ip" ]]; then
    log_error "No public IP for $instance_id — cannot use SSH fallback" >&2
    return 1
  fi
  local key_path="${SSH_KEY_PATH:-$HOME/.ssh/${EC2_KEY_NAME}.pem}"
  if [[ ! -f "$key_path" ]]; then
    log_error "SSH key not found at $key_path (set SSH_KEY_PATH to override)" >&2
    return 1
  fi
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    -i "$key_path" "ubuntu@${ip}" 'sudo bash -s' < "$script_path"
}

# remote_run <instance-id> <local-script-path> [comment]
# Dispatches to SSM (default/preferred) or SSH (only if CKNE_TRANSPORT=ssh,
# which cluster-bootstrap.sh sets ONLY when ENABLE_SSH=true and SSM
# registration failed).
remote_run() {
  local instance_id="$1" script_path="$2" comment="${3:-remote-command}"
  if [[ "${CKNE_TRANSPORT:-ssm}" == "ssh" ]]; then
    ssh_run "$instance_id" "$script_path"
  else
    ssm_run "$instance_id" "$script_path" "$comment"
  fi
}

# render_kubeadm_config <output-path>
# Renders config/kubeadm.config.template using the current shell environment
# (ADVERTISE_ADDRESS, CONTROL_PLANE_ENDPOINT, NODE_NAME, KUBERNETES_VERSION_FULL,
# POD_CIDR, SERVICE_CIDR must already be exported by the caller).
render_kubeadm_config() {
  local out_path="$1"
  local template="$KUBEADM_SETUP_DIR/config/kubeadm.config.template"
  require_cmd envsubst
  envsubst '${ADVERTISE_ADDRESS} ${CONTROL_PLANE_ENDPOINT} ${NODE_NAME} ${KUBERNETES_VERSION_FULL} ${POD_CIDR} ${SERVICE_CIDR}' \
    < "$template" > "$out_path"
}
