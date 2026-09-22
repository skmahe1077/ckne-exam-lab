#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-01"
NAMESPACE="ckne-atm-01"
GATEWAY_NAME="atm-gw"
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

# Gateway must be accepted/programmed by Cilium's controller.
GW_PROGRAMMED="$(kubectl -n "$NAMESPACE" get gateway "$GATEWAY_NAME" -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")"
if [[ "$GW_PROGRAMMED" == "True" ]]; then
  ckne_pass "Gateway $GATEWAY_NAME is Programmed"
else
  ckne_fail_check "Gateway $GATEWAY_NAME is not Programmed (status: '${GW_PROGRAMMED:-<missing>}')"
  RESULT=1
fi

SVC_NAME="cilium-gateway-${GATEWAY_NAME}"
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

# ckne_check <description> <host-header> <path> <expected-substring>
# Runs a throwaway checker Pod that sends one HTTP request with the given
# Host header and path, and confirms the body contains the expected
# backend's identifying string. Retries a few times to absorb the few
# seconds it can take Envoy to reprogram after an HTTPRoute change.
ckne_check() {
  local desc="$1" host_hdr="$2" path="$3" expect="$4"
  local attempt out
  for attempt in 1 2 3 4 5; do
    out="$(kubectl -n "$NAMESPACE" run "atm01-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
      --command -- wget -q -T 5 -O- --header="Host: ${host_hdr}" "http://${GW_IP}${path}" 2>/dev/null || true)"
    if printf '%s' "$out" | grep -q "$expect"; then
      ckne_pass "$desc"
      return 0
    fi
    sleep 3
  done
  ckne_fail_check "$desc (expected body to contain '$expect', got: '$out')"
  return 1
}

ckne_check "Host blue.ckne.local routes to the blue backend" "blue.ckne.local" "/" "blue-backend" || RESULT=1
ckne_check "Host green.ckne.local routes to the green backend" "green.ckne.local" "/" "green-backend" || RESULT=1
ckne_check "Path /blue on app.ckne.local routes to the blue backend" "app.ckne.local" "/blue" "blue-backend" || RESULT=1
ckne_check "Path /green on app.ckne.local routes to the green backend" "app.ckne.local" "/green" "green-backend" || RESULT=1

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
