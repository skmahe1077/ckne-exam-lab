#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-02"
NAMESPACE="ckne-atm-02"
GATEWAY_NAME="atm-gw"
CHECKER_IMAGE="busybox:1.36"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

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

# ckne_check <description> <extra-header-or-empty> <expected-substring>
ckne_check() {
  local desc="$1" hdr="$2" expect="$3"
  local attempt out
  for attempt in 1 2 3 4 5; do
    if [[ -n "$hdr" ]]; then
      out="$(kubectl -n "$NAMESPACE" run "atm02-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
        --command -- wget -q -T 5 -O- --header="Host: app.ckne.local" --header="$hdr" "http://${GW_IP}/" 2>/dev/null || true)"
    else
      out="$(kubectl -n "$NAMESPACE" run "atm02-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
        --command -- wget -q -T 5 -O- --header="Host: app.ckne.local" "http://${GW_IP}/" 2>/dev/null || true)"
    fi
    if printf '%s' "$out" | grep -q "$expect"; then
      ckne_pass "$desc"
      return 0
    fi
    sleep 3
  done
  ckne_fail_check "$desc (expected body to contain '$expect', got: '$out')"
  return 1
}

ckne_check "Request without X-Canary header reaches the stable backend" "" "stable-backend" || RESULT=1
ckne_check "Request with X-Canary: true reaches the canary backend" "X-Canary: true" "canary-backend" || RESULT=1
ckne_check "Request with X-Canary: false still reaches the stable backend" "X-Canary: false" "stable-backend" || RESULT=1

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
