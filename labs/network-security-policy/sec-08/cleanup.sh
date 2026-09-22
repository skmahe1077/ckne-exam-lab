#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-08"
NAMESPACE="ckne-sec-08"
LOCK_RESOURCE="cilium-config"
LOCK_NAMESPACE="ckne-lab-system"
LOCK_CM="ckne-lock-${LOCK_RESOURCE}"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

CURRENT_HOLDER=""
if kubectl -n "$LOCK_NAMESPACE" get configmap "$LOCK_CM" >/dev/null 2>&1; then
  CURRENT_HOLDER="$(kubectl -n "$LOCK_NAMESPACE" get configmap "$LOCK_CM" -o jsonpath='{.data.holder}' 2>/dev/null || true)"
fi

if [[ "$CURRENT_HOLDER" == "$TASK_ID" ]]; then
  ckne_log "Lock '$LOCK_RESOURCE' is held by $TASK_ID — reverting WireGuard transparent encryption first"
  helm upgrade cilium cilium/cilium --reuse-values \
    --set encryption.enabled=false \
    --namespace kube-system --wait --timeout 5m
  kubectl -n kube-system rollout status daemonset/cilium --timeout=180s || true
  "$REPO_ROOT/shared/scripts/lock.sh" release "$LOCK_RESOURCE" "$TASK_ID"
elif [[ -z "$CURRENT_HOLDER" ]]; then
  ckne_log "Lock '$LOCK_RESOURCE' is already free — nothing to revert/release."
else
  ckne_warn "Lock '$LOCK_RESOURCE' is held by '$CURRENT_HOLDER', not $TASK_ID — leaving Cilium encryption config untouched."
fi

ckne_log "Deleting namespace $NAMESPACE"
ckne_delete_namespace "$NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE"; then
  ckne_log "Cleanup verified: $NAMESPACE no longer exists."
else
  ckne_fail "Namespace $NAMESPACE still exists after cleanup"
fi

exit 0
