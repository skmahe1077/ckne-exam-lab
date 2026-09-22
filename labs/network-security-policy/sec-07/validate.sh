#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-07"
NAMESPACE="ckne-sec-07"

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

READY="$(kubectl -n "$NAMESPACE" get deployment client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment client is Ready"
else
  ckne_fail_check "Deployment client is not Ready (readyReplicas=${READY:-0})"
  RESULT=1
fi

CLIENT_POD="$(kubectl -n "$NAMESPACE" get pods -l app=client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$CLIENT_POD" ]]; then
  ckne_fail_check "No client Pod found"
  echo "FAIL"
  exit 1
fi

# Real runtime behaviour: DNS resolution must work.
if kubectl -n "$NAMESPACE" exec "$CLIENT_POD" -- nslookup kubernetes.default.svc.cluster.local >/tmp/sec07-dns.out 2>&1; then
  ckne_pass "DNS resolution (kubernetes.default.svc.cluster.local) succeeds from client"
else
  ckne_fail_check "DNS resolution failed from client — egress to kube-dns (UDP/TCP 53) is not allowed"
  cat /tmp/sec07-dns.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec07-dns.out

# Real runtime behaviour: arbitrary non-DNS egress must still be blocked.
if kubectl -n "$NAMESPACE" exec "$CLIENT_POD" -- nc -z -w 5 1.1.1.1 443 >/tmp/sec07-egress.out 2>&1; then
  ckne_fail_check "client reached an external IP (1.1.1.1:443) — non-DNS egress must remain blocked"
  RESULT=1
else
  ckne_pass "Arbitrary outbound (1.1.1.1:443) is correctly blocked"
fi
rm -f /tmp/sec07-egress.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
