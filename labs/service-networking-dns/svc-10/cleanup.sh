#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-10"
NAMESPACE="ckne-svc-10"
BACKEND_NAMESPACE="ckne-svc-10-backend"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

ckne_log "Deleting namespaces $NAMESPACE and $BACKEND_NAMESPACE"
ckne_delete_namespace "$NAMESPACE"
ckne_delete_namespace "$BACKEND_NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE" && ckne_verify_namespace_gone "$BACKEND_NAMESPACE"; then
  ckne_log "Cleanup verified: $NAMESPACE and $BACKEND_NAMESPACE no longer exist."
else
  ckne_fail "One or both namespaces still exist after cleanup"
fi

# This lab only references the shared GatewayClass "cilium" by name — it
# never creates or edits it, so no shared/cluster-scoped resources were
# modified and no lock to release.
exit 0
