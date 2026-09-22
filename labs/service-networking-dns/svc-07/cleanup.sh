#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-07"
NAMESPACE="ckne-svc-07"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

ckne_log "Deleting namespace $NAMESPACE"
ckne_delete_namespace "$NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE"; then
  ckne_log "Cleanup verified: $NAMESPACE no longer exists."
else
  ckne_fail "Namespace $NAMESPACE still exists after cleanup"
fi

# This lab is read-only against shared/cluster-scoped resources (it only
# inspects kube-proxy's node-level iptables state, never mutates it) — no
# lock was acquired, so there is nothing to release.
exit 0
