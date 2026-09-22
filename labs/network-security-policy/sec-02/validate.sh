#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-02"
NAMESPACE="ckne-sec-02"

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

READY="$(kubectl -n "$NAMESPACE" get pod client -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown)"
if [[ "$READY" == "Running" ]]; then
  ckne_pass "Pod client is Running"
else
  ckne_fail_check "Pod client is not Running (phase: $READY) — this is a precondition, fix the environment first"
  RESULT=1
fi

# DNS must resolve (default-deny-egress blocks DNS unless explicitly allowed).
if kubectl -n "$NAMESPACE" exec client -- timeout 5 nslookup allowed-svc.${NAMESPACE}.svc.cluster.local >/tmp/sec02-dns.out 2>&1; then
  ckne_pass "client can resolve DNS (allowed-svc.${NAMESPACE}.svc.cluster.local)"
else
  ckne_fail_check "client could NOT resolve DNS — egress to CoreDNS (UDP/TCP 53) is missing"
  cat /tmp/sec02-dns.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec02-dns.out

# Real traffic: client MUST be able to reach allowed-svc.
if kubectl -n "$NAMESPACE" exec client -- wget -q -T 5 -O- "http://allowed-svc.${NAMESPACE}.svc.cluster.local" >/tmp/sec02-allowed.out 2>&1; then
  ckne_pass "client can reach allowed-svc"
else
  ckne_fail_check "client could NOT reach allowed-svc — the egress-allow rule is missing or scoped incorrectly"
  cat /tmp/sec02-allowed.out >&2 || true
  RESULT=1
fi
rm -f /tmp/sec02-allowed.out

# Real traffic: client must remain unable to reach blocked-svc.
if kubectl -n "$NAMESPACE" exec client -- wget -q -T 5 -O- "http://blocked-svc.${NAMESPACE}.svc.cluster.local" >/tmp/sec02-blocked.out 2>&1; then
  ckne_fail_check "client reached blocked-svc — egress is too permissive (should only allow allowed-target + DNS)"
  RESULT=1
else
  ckne_pass "client is correctly blocked from reaching blocked-svc"
fi
rm -f /tmp/sec02-blocked.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
