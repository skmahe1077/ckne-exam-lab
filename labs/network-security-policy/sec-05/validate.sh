#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-05"
NAMESPACE="ckne-sec-05"
CLIENTS_NAMESPACE="ckne-sec-05-clients"

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
if ! kubectl get namespace "$CLIENTS_NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $CLIENTS_NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is Ready"
else
  ckne_fail_check "Deployment backend is not Ready (${READY:-0}/1) — this is a precondition, fix the environment first"
  RESULT=1
fi

TRUST_LABEL="$(kubectl get namespace "$CLIENTS_NAMESPACE" -o jsonpath='{.metadata.labels.team}' 2>/dev/null || true)"
if [[ "$TRUST_LABEL" == "payments" ]]; then
  ckne_pass "$CLIENTS_NAMESPACE carries team=payments"
else
  ckne_fail_check "$CLIENTS_NAMESPACE is missing the team=payments label — this is a precondition, do not remove it"
  RESULT=1
fi

URL="http://backend.${NAMESPACE}.svc.cluster.local"

# frontend-a: trusted namespace AND correct role -> must succeed regardless of AND/OR bug.
if kubectl -n "$CLIENTS_NAMESPACE" exec frontend-a -- wget -q -T 5 -O- "$URL" >/tmp/sec05-a.out 2>&1; then
  ckne_pass "frontend-a (trusted namespace + role=frontend) can reach backend"
else
  ckne_fail_check "frontend-a (trusted namespace + role=frontend) could NOT reach backend — the allow rule is missing entirely"
  cat /tmp/sec05-a.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec05-a.out

# worker-a: trusted namespace but WRONG role -> must be blocked. Succeeding here means
# the policy incorrectly used OR (namespaceSelector alone is enough) instead of AND.
if kubectl -n "$CLIENTS_NAMESPACE" exec worker-a -- wget -q -T 5 -O- "$URL" >/tmp/sec05-b.out 2>&1; then
  ckne_fail_check "worker-a (trusted namespace, role=worker) reached backend — namespaceSelector and podSelector must be combined as AND (one from-entry), not OR (two from-entries)"
  RESULT=1
else
  ckne_pass "worker-a (trusted namespace, wrong role) is correctly blocked from reaching backend"
fi
rm -f /tmp/sec05-b.out

# rogue-frontend: correct role but WRONG (untrusted) namespace -> must be blocked. Succeeding
# here means the policy incorrectly used OR (podSelector alone is enough) instead of AND.
if kubectl -n "$NAMESPACE" exec rogue-frontend -- wget -q -T 5 -O- "$URL" >/tmp/sec05-c.out 2>&1; then
  ckne_fail_check "rogue-frontend (role=frontend, untrusted namespace) reached backend — namespaceSelector and podSelector must be combined as AND (one from-entry), not OR (two from-entries)"
  RESULT=1
else
  ckne_pass "rogue-frontend (untrusted namespace, correct-looking role) is correctly blocked from reaching backend"
fi
rm -f /tmp/sec05-c.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
