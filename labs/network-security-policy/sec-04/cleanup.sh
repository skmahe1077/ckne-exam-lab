#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-04"
NAMESPACE="ckne-sec-04"
CLIENTS_NAMESPACE="ckne-sec-04-clients"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

ckne_log "Deleting namespaces $NAMESPACE and $CLIENTS_NAMESPACE"
ckne_delete_namespace "$NAMESPACE"
ckne_delete_namespace "$CLIENTS_NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE" && ckne_verify_namespace_gone "$CLIENTS_NAMESPACE"; then
  ckne_log "Cleanup verified: $NAMESPACE and $CLIENTS_NAMESPACE no longer exist."
else
  ckne_fail "One or both namespaces still exist after cleanup"
fi

# No shared/cluster-scoped resources were modified by this lab (no lock to release).
exit 0
