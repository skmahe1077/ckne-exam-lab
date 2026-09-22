#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-02"
NAMESPACE="ckne-svc-02"

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

SVC_TYPE="$(kubectl -n "$NAMESPACE" get svc web -o jsonpath='{.spec.type}' 2>/dev/null || true)"
NODE_PORT="$(kubectl -n "$NAMESPACE" get svc web -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"
if [[ "$SVC_TYPE" == "NodePort" && -n "$NODE_PORT" && "$NODE_PORT" -ge 30000 && "$NODE_PORT" -le 32767 ]]; then
  ckne_pass "Service web is type NodePort with nodePort $NODE_PORT (30000-32767)"
else
  ckne_fail_check "Service web is not a valid NodePort Service (type=$SVC_TYPE nodePort=${NODE_PORT:-<none>})"
  RESULT=1
fi

EP_IPS="$(kubectl -n "$NAMESPACE" get endpoints web -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
EP_COUNT=0
for ip in $EP_IPS; do
  EP_COUNT=$((EP_COUNT + 1))
done
if [[ "$EP_COUNT" -eq 2 ]]; then
  ckne_pass "Service web has 2 healthy Endpoints ($EP_IPS)"
else
  ckne_fail_check "Service web has $EP_COUNT Endpoints, expected 2"
  RESULT=1
fi

# Real runtime behaviour check: send traffic to a node's private IP on the
# allocated nodePort, from inside the cluster (this cluster's security
# group only opens 30000-32767 to traffic originating in-cluster).
NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
if [[ -z "$NODE_IP" || -z "$NODE_PORT" ]]; then
  ckne_fail_check "Could not determine a node IP or nodePort to test against"
  RESULT=1
else
  if kubectl -n "$NAMESPACE" run svc02-checker --image=busybox:1.36 --restart=Never --rm -i \
      --command -- wget -q -T 5 -O- "http://${NODE_IP}:${NODE_PORT}" >/tmp/svc02-checker.out 2>&1; then
    ckne_pass "NodePort $NODE_PORT on node $NODE_IP routes traffic to web Pods successfully"
  else
    ckne_fail_check "NodePort $NODE_PORT on node $NODE_IP did not respond — check the Service's targetPort"
    cat /tmp/svc02-checker.out >&2 || true
    RESULT=1
  fi
  rm -f /tmp/svc02-checker.out
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
