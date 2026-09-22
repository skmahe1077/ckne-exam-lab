#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-09"
NAMESPACE="ckne-svc-09"
CHECKER_IMAGE="busybox:1.36"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

# Precondition (not the task): the shared GatewayClass must be Accepted.
GWC_ACCEPTED="$(kubectl get gatewayclass cilium -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")"
if [[ "$GWC_ACCEPTED" == "True" ]]; then
  ckne_pass "GatewayClass 'cilium' is Accepted"
else
  ckne_fail_check "GatewayClass 'cilium' is not Accepted — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

WEB_READY="$(kubectl -n "$NAMESPACE" get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${WEB_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment web is 1/1 Ready"
else
  ckne_fail_check "Deployment web is ${WEB_READY:-0}/1 Ready"
  RESULT=1
fi

# Find the student's Gateway (any name) in this namespace using GatewayClass "cilium".
GW_NAME="$(kubectl -n "$NAMESPACE" get gateway -o jsonpath='{range .items[?(@.spec.gatewayClassName=="cilium")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -n1 || true)"
if [[ -z "$GW_NAME" ]]; then
  ckne_fail_check "No Gateway using gatewayClassName: cilium was found in $NAMESPACE — create one"
  echo "FAIL"
  exit 1
fi
ckne_pass "Found Gateway '$GW_NAME' using gatewayClassName: cilium"

GW_PROGRAMMED="$(kubectl -n "$NAMESPACE" get gateway "$GW_NAME" -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")"
if [[ "$GW_PROGRAMMED" == "True" ]]; then
  ckne_pass "Gateway $GW_NAME is Programmed"
else
  ckne_fail_check "Gateway $GW_NAME is not Programmed (status: '${GW_PROGRAMMED:-<missing>}')"
  RESULT=1
fi

# Cilium's Gateway implementation auto-creates a ClusterIP Service named
# cilium-gateway-<gateway-name> for every Gateway it programs.
SVC_NAME="cilium-gateway-${GW_NAME}"
GW_IP=""
for _ in $(seq 1 15); do
  GW_IP="$(kubectl -n "$NAMESPACE" get svc "$SVC_NAME" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")"
  [[ -n "$GW_IP" && "$GW_IP" != "None" ]] && break
  sleep 2
done
if [[ -z "$GW_IP" || "$GW_IP" == "None" ]]; then
  ckne_fail_check "Could not find a ClusterIP for Service $SVC_NAME (Cilium's Gateway-managed Service) — is the Gateway healthy?"
  echo "FAIL"
  exit 1
fi

# Real HTTP request through the Gateway must reach the "web" backend.
FOUND=0
for attempt in 1 2 3 4 5; do
  OUT="$(kubectl -n "$NAMESPACE" run "svc09-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://${GW_IP}/" 2>/dev/null || true)"
  if printf '%s' "$OUT" | grep -q "svc09-backend"; then
    FOUND=1
    break
  fi
  sleep 3
done
if [[ "$FOUND" -eq 1 ]]; then
  ckne_pass "A real HTTP request through the Gateway reaches the web backend"
else
  ckne_fail_check "A real HTTP request through the Gateway did not reach the web backend (expected body to contain 'svc09-backend')"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
