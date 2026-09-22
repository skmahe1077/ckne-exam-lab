#!/usr/bin/env bash
set -Eeuo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

TASK_ID="SEC-04"
NAMESPACE="ckne-sec-04"
CLIENTS_NAMESPACE="ckne-sec-04-clients"

ckne_log "Resetting $TASK_ID"

"$LAB_DIR/cleanup.sh"

if ! ckne_verify_namespace_gone "$NAMESPACE" || ! ckne_verify_namespace_gone "$CLIENTS_NAMESPACE"; then
  ckne_fail "Cleanup did not fully remove $NAMESPACE / $CLIENTS_NAMESPACE — aborting reset"
fi

"$LAB_DIR/setup.sh"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || ckne_fail "Setup did not (re)create $NAMESPACE"
kubectl get namespace "$CLIENTS_NAMESPACE" >/dev/null 2>&1 || ckne_fail "Setup did not (re)create $CLIENTS_NAMESPACE"
ckne_log "Reset complete: $TASK_ID is back to its starting state."
