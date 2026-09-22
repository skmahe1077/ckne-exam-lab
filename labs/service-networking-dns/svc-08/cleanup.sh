#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-08"
NAMESPACE="ckne-svc-08"
LOCK_RESOURCE="coredns"
BACKUP_CM="svc08-coredns-backup"
LOCK_NS="ckne-lab-system"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

if kubectl -n "$LOCK_NS" get configmap "$BACKUP_CM" >/dev/null 2>&1; then
  ckne_log "Restoring the original kube-system/coredns Corefile"
  ORIGINAL_COREFILE="$(kubectl -n "$LOCK_NS" get configmap "$BACKUP_CM" -o jsonpath='{.data.Corefile}')"
  if [[ -n "$ORIGINAL_COREFILE" ]]; then
    kubectl -n kube-system create configmap coredns \
      --from-literal=Corefile="$ORIGINAL_COREFILE" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n kube-system rollout restart deployment coredns
    kubectl -n kube-system rollout status deployment/coredns --timeout=120s
  else
    ckne_warn "Backup ConfigMap was empty — not restoring (nothing to restore from)"
  fi
  kubectl -n "$LOCK_NS" delete configmap "$BACKUP_CM" --ignore-not-found
else
  ckne_log "No backup found — CoreDNS was likely already restored (safe re-run)."
fi

ckne_log "Releasing lock on '$LOCK_RESOURCE'"
"$REPO_ROOT/shared/scripts/lock.sh" release "$LOCK_RESOURCE" "$TASK_ID"

ckne_log "Deleting namespace $NAMESPACE"
ckne_delete_namespace "$NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE"; then
  ckne_log "Cleanup verified: $NAMESPACE no longer exists."
else
  ckne_fail "Namespace $NAMESPACE still exists after cleanup"
fi

FINAL_COREFILE="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' 2>/dev/null || echo "")"
if printf '%s' "$FINAL_COREFILE" | grep -q 'svc08test.example'; then
  ckne_fail "kube-system/coredns Corefile still contains svc08test.example after cleanup — restoration failed"
fi

exit 0
