#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-03"
NAMESPACE="ckne-cni-03"

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

SERVER_READY="$(kubectl -n "$NAMESPACE" get deployment server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${SERVER_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment server is 1/1 Ready"
else
  ckne_fail_check "Deployment server is ${SERVER_READY:-0}/1 Ready"
  RESULT=1
fi

TOOLBOX_PHASE="$(kubectl -n "$NAMESPACE" get pod toolbox -o jsonpath='{.status.phase}' 2>/dev/null || echo "")"
if [[ "$TOOLBOX_PHASE" == "Running" ]]; then
  ckne_pass "Pod toolbox is Running"
else
  ckne_fail_check "Pod toolbox is not Running (phase: ${TOOLBOX_PHASE:-unknown})"
  RESULT=1
fi

# Observational state check: no outbound DROP rule for tcp/80 should remain
# in toolbox's own OUTPUT chain.
if kubectl -n "$NAMESPACE" exec toolbox -- iptables -C OUTPUT -p tcp --dport 80 -j DROP >/dev/null 2>&1; then
  ckne_fail_check "toolbox's iptables OUTPUT chain still has a rule dropping outbound tcp/80"
  RESULT=1
else
  ckne_pass "toolbox's iptables OUTPUT chain no longer drops outbound tcp/80"
fi

# Real runtime behaviour: toolbox must actually be able to reach server.
SERVER_IP="$(kubectl -n "$NAMESPACE" get svc server -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")"
if [[ -n "$SERVER_IP" ]]; then
  if kubectl -n "$NAMESPACE" exec toolbox -- curl -s -o /dev/null -m 5 -w '%{http_code}' "http://${SERVER_IP}:80" 2>/tmp/cni03-checker.out | grep -q '^200$'; then
    ckne_pass "toolbox can reach server ($SERVER_IP:80) over tcp/80"
  else
    ckne_fail_check "toolbox cannot reach server ($SERVER_IP:80) over tcp/80"
    cat /tmp/cni03-checker.out >&2 || true
    RESULT=1
  fi
  rm -f /tmp/cni03-checker.out
else
  ckne_fail_check "Could not determine server Service ClusterIP"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
