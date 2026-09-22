#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-04"
NAMESPACE="ckne-sec-04"
CLIENTS_NAMESPACE="ckne-sec-04-clients"

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

TRUST_LABEL="$(kubectl get namespace "$CLIENTS_NAMESPACE" -o jsonpath='{.metadata.labels.network-access}' 2>/dev/null || true)"
if [[ "$TRUST_LABEL" == "trusted" ]]; then
  ckne_pass "$CLIENTS_NAMESPACE carries network-access=trusted"
else
  ckne_fail_check "$CLIENTS_NAMESPACE is missing the network-access=trusted label — this is a precondition, do not remove it"
  RESULT=1
fi

# Real traffic: client-a (in the trusted namespace) MUST be able to reach backend.
if kubectl -n "$CLIENTS_NAMESPACE" exec client-a -- wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local" >/tmp/sec04-allowed.out 2>&1; then
  ckne_pass "client-a (in trusted namespace $CLIENTS_NAMESPACE) can reach backend"
else
  ckne_fail_check "client-a (in trusted namespace $CLIENTS_NAMESPACE) could NOT reach backend — the namespace-selector allow rule is missing or scoped incorrectly"
  cat /tmp/sec04-allowed.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec04-allowed.out

# Real traffic: untrusted-client (in backend's own, untrusted namespace) must be blocked.
if kubectl -n "$NAMESPACE" exec untrusted-client -- wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local" >/tmp/sec04-blocked.out 2>&1; then
  ckne_fail_check "untrusted-client reached backend — ingress is too permissive (should only allow namespaces labeled network-access=trusted)"
  RESULT=1
else
  ckne_pass "untrusted-client (untrusted namespace) is correctly blocked from reaching backend"
fi
rm -f /tmp/sec04-blocked.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
