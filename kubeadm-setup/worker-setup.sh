#!/usr/bin/env bash
# ==============================================================================
# Worker node setup — runs ON a worker EC2 instance as root.
#
# Contract (set up by whatever invokes this script — normally
# cluster-bootstrap.sh, which concatenates a small header before this file's
# contents into a single SSM Run Command so both execute in the same shell):
#   - NODE_NAME is exported (hostname to assign to this node)
#   - JOIN_COMMAND is exported (the full `kubeadm join ...` command, including
#     its short-lived token — never logged or persisted beyond this run)
#
# Idempotent: if the node has already joined
# (/etc/kubernetes/kubelet.conf exists), this script skips `kubeadm join`.
# ==============================================================================
set -Eeuo pipefail

log() { printf '[worker-setup] %s\n' "$*"; }

if [[ "$(id -u)" -ne 0 ]]; then
  echo "worker-setup.sh must run as root" >&2
  exit 1
fi

: "${NODE_NAME:?NODE_NAME must be exported before running worker-setup.sh}"
: "${JOIN_COMMAND:?JOIN_COMMAND must be exported before running worker-setup.sh}"

CURRENT_HOSTNAME="$(hostname)"
if [[ "$CURRENT_HOSTNAME" != "$NODE_NAME" ]]; then
  log "Setting hostname: $NODE_NAME"
  hostnamectl set-hostname "$NODE_NAME"
fi

if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  log "Node already joined to a cluster — skipping kubeadm join."
else
  log "Joining cluster"
  eval "$JOIN_COMMAND" --node-name "$NODE_NAME"
fi

log "worker-setup.sh completed on $(hostname)"
