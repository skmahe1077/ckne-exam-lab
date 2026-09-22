#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-02"
NAMESPACE="ckne-obs-02"

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

# This lab only ever READS the shared CoreDNS Deployment/Pods — it never
# modifies the CoreDNS Corefile or ConfigMap, so no lock was acquired and
# none needs to be released.
exit 0
