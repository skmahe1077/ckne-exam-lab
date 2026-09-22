#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-02"
NAMESPACE="ckne-cni-02"

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

CLIENT_READY="$(kubectl -n "$NAMESPACE" get deployment client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${CLIENT_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment client is 1/1 Ready"
else
  ckne_fail_check "Deployment client is ${CLIENT_READY:-0}/1 Ready"
  RESULT=1
fi

# Pod CIDR / IPAM check: every Pod's IP must actually come from the
# cluster's configured Pod CIDR (10.244.0.0/16).
POD_IPS="$(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[*].status.podIP}')"
BAD_IP=0
for ip in $POD_IPS; do
  case "$ip" in
    10.244.*) ;;
    *) BAD_IP=1 ;;
  esac
done
if [[ -n "$POD_IPS" && "$BAD_IP" -eq 0 ]]; then
  ckne_pass "All Pods have IPs inside the cluster's Pod CIDR 10.244.0.0/16 ($POD_IPS)"
else
  ckne_fail_check "One or more Pods do not have a valid Pod CIDR IP (got: '$POD_IPS')"
  RESULT=1
fi

if kubectl -n "$NAMESPACE" get networkpolicy allow-server-ingress >/dev/null 2>&1; then
  ckne_pass "NetworkPolicy allow-server-ingress still exists (task is to fix it, not remove it)"
else
  ckne_fail_check "NetworkPolicy allow-server-ingress is missing — the task is to correct its CIDR, not delete it"
  RESULT=1
fi

# Real runtime behaviour: send actual traffic from client to server's Pod IP.
SERVER_IP="$(kubectl -n "$NAMESPACE" get pods -l app=server -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")"
CLIENT_POD="$(kubectl -n "$NAMESPACE" get pods -l app=client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"
if [[ -n "$SERVER_IP" && -n "$CLIENT_POD" ]]; then
  if kubectl -n "$NAMESPACE" exec "$CLIENT_POD" -- wget -q -T 5 -O- "http://${SERVER_IP}:80" >/tmp/cni02-checker.out 2>&1; then
    ckne_pass "client can reach server ($SERVER_IP:80) — NetworkPolicy now permits the actual Pod CIDR"
  else
    ckne_fail_check "client cannot reach server ($SERVER_IP:80) — traffic is still being blocked"
    RESULT=1
  fi
  rm -f /tmp/cni02-checker.out
else
  ckne_fail_check "Could not determine server Pod IP or client Pod name to test connectivity"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
