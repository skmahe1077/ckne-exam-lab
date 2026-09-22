#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-06"
NAMESPACE="ckne-sec-06"

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
  ckne_fail_check "Deployment backend is not Ready (readyReplicas=${READY:-0})"
  RESULT=1
fi

if ! kubectl -n "$NAMESPACE" get pod client-a client-b >/dev/null 2>&1; then
  ckne_fail_check "client-a/client-b Pods are missing — run: make start LAB=$TASK_ID"
  exit 1
fi

CLIENT_A_IP="$(kubectl -n "$NAMESPACE" get pod client-a -o jsonpath='{.status.podIP}' 2>/dev/null || true)"
CLIENT_B_IP="$(kubectl -n "$NAMESPACE" get pod client-b -o jsonpath='{.status.podIP}' 2>/dev/null || true)"

# Real runtime behaviour: client-a's node Pod-CIDR range must be allowed
# through the ipBlock rule; client-b's node Pod-CIDR range must be excluded.
if kubectl -n "$NAMESPACE" exec client-a -- wget -q -T 5 -O- http://backend >/tmp/sec06-a.out 2>&1; then
  ckne_pass "client-a (IP $CLIENT_A_IP) CAN reach backend — its node's Pod CIDR is correctly allowed"
else
  ckne_fail_check "client-a (IP $CLIENT_A_IP) could NOT reach backend — it should be allowed by the ipBlock rule"
  cat /tmp/sec06-a.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec06-a.out

if kubectl -n "$NAMESPACE" exec client-b -- wget -q -T 5 -O- http://backend >/tmp/sec06-b.out 2>&1; then
  ckne_fail_check "client-b (IP $CLIENT_B_IP) CAN reach backend — its node's Pod CIDR must be excluded via 'except'"
  RESULT=1
else
  ckne_pass "client-b (IP $CLIENT_B_IP) is correctly blocked from reaching backend"
fi
rm -f /tmp/sec06-b.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
