#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-01"
NAMESPACE="ckne-obs-01"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0

ckne_require_kubectl

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

# Precondition: backend must still be healthy (not part of the fix).
BACKEND_READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${BACKEND_READY:-0}" == "1" ]]; then
  ckne_pass "backend Deployment is 1/1 Ready (precondition)"
else
  ckne_fail_check "backend Deployment is ${BACKEND_READY:-0}/1 Ready — this should not have changed"
  RESULT=1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment netprobe -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
DESIRED="$(kubectl -n "$NAMESPACE" get deployment netprobe -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 2)"
if [[ "${READY:-0}" == "2" && "$DESIRED" == "2" ]]; then
  ckne_pass "Deployment netprobe is 2/2 Ready"
else
  ckne_fail_check "Deployment netprobe is ${READY:-0}/${DESIRED:-2} Ready"
  RESULT=1
fi

# Real health check: no netprobe Pod may be in (or recently in) a crash-loop.
BAD_PODS=""
POD_NAMES="$(kubectl -n "$NAMESPACE" get pods -l app=netprobe -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
for pod in $POD_NAMES; do
  RESTARTS="$(kubectl -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo 0)"
  WAITING_REASON="$(kubectl -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
  if [[ "$WAITING_REASON" == "CrashLoopBackOff" ]]; then
    BAD_PODS="$BAD_PODS $pod(${WAITING_REASON})"
  fi
done
if [[ -z "$BAD_PODS" ]]; then
  ckne_pass "No netprobe Pod is in CrashLoopBackOff"
else
  ckne_fail_check "netprobe Pod(s) still crash-looping:$BAD_PODS"
  RESULT=1
fi

# Real runtime behaviour check: the fixed netprobe container must actually be
# logging successful reaches, not just "Running".
OK_FOUND=0
for pod in $POD_NAMES; do
  if kubectl -n "$NAMESPACE" logs "$pod" --tail=20 2>/dev/null | grep -q "^OK: reached"; then
    OK_FOUND=$((OK_FOUND + 1))
  fi
done
if [[ "$OK_FOUND" -ge 1 ]]; then
  ckne_pass "At least one netprobe Pod logs successful reaches of the backend ($OK_FOUND/2)"
else
  ckne_fail_check "No netprobe Pod logs a successful reach of the backend yet"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
