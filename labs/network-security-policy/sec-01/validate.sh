#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-01"
NAMESPACE="ckne-sec-01"

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

# Real traffic: client-frontend (role=frontend) MUST be able to reach backend.
if kubectl -n "$NAMESPACE" exec client-frontend -- wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local" >/tmp/sec01-allowed.out 2>&1; then
  ckne_pass "client-frontend (role=frontend) can reach backend"
else
  ckne_fail_check "client-frontend (role=frontend) could NOT reach backend — the ingress-allow rule is missing or scoped incorrectly"
  cat /tmp/sec01-allowed.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec01-allowed.out

# Real traffic: client-other (role=other) must remain blocked.
if kubectl -n "$NAMESPACE" exec client-other -- wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local" >/tmp/sec01-blocked.out 2>&1; then
  ckne_fail_check "client-other (role=other) reached backend — ingress is too permissive (should only allow role=frontend)"
  RESULT=1
else
  ckne_pass "client-other (role=other) is correctly blocked from reaching backend"
fi
rm -f /tmp/sec01-blocked.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
