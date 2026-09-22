#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-04"
NAMESPACE="ckne-atm-04"

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

# The Issuer/Certificate are namespace-scoped and are deleted along with the
# namespace. No cluster-scoped resources or locks were used by this lab.
exit 0
