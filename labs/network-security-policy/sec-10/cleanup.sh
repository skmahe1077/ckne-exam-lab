#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-10"
NAMESPACE="ckne-sec-10"

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

# The PeerAuthentication/AuthorizationPolicy created by this lab are both
# namespace-scoped (never istio-system-scoped) and are deleted automatically
# with the namespace above — no cluster-scoped resource and no lock to
# release. Istio's mesh-wide config (istiod) is never touched by this lab.
exit 0
