#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-03"
NAMESPACE="ckne-sec-03"

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

READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is Ready"
else
  ckne_fail_check "Deployment backend is not Ready (${READY:-0}/1) — this is a precondition, fix the environment first"
  RESULT=1
fi

# A NetworkPolicy must actually exist selecting backend for Ingress.
NP_COUNT="$(kubectl -n "$NAMESPACE" get networkpolicy -o name 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${NP_COUNT:-0}" -gt 0 ]]; then
  ckne_pass "At least one NetworkPolicy exists in $NAMESPACE"
else
  ckne_fail_check "No NetworkPolicy found in $NAMESPACE — backend is still open to all Pods"
  RESULT=1
fi

# Real traffic: client-frontend (role=frontend) MUST be able to reach backend.
if kubectl -n "$NAMESPACE" exec client-frontend -- wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local" >/tmp/sec03-allowed.out 2>&1; then
  ckne_pass "client-frontend (role=frontend) can reach backend"
else
  ckne_fail_check "client-frontend (role=frontend) could NOT reach backend — the pod-selector allow rule is missing or scoped incorrectly"
  cat /tmp/sec03-allowed.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec03-allowed.out

# Real traffic: client-other (role=other) must be blocked.
if kubectl -n "$NAMESPACE" exec client-other -- wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local" >/tmp/sec03-blocked.out 2>&1; then
  ckne_fail_check "client-other (role=other) reached backend — the pod-selector rule is too permissive (should only allow role=frontend)"
  RESULT=1
else
  ckne_pass "client-other (role=other) is correctly blocked from reaching backend"
fi
rm -f /tmp/sec03-blocked.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
