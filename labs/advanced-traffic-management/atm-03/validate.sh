#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-03"
NAMESPACE="ckne-atm-03"
GATEWAY_NAME="atm-gw"
CHECKER_IMAGE="busybox:1.36"
NUM_REQUESTS=40
MIN_SUCCESSFUL=30
TARGET_STABLE_PCT=80
TARGET_CANARY_PCT=20
TOLERANCE_PCT=25

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

# The two weights must actually be unequal and roughly an 80/20 ratio in
# the object itself (a structural precondition, checked before we bother
# sending any traffic) — this does not reveal the fix, it just avoids
# wasting 40 requests against an obviously-still-even split.
STABLE_WEIGHT="$(kubectl -n "$NAMESPACE" get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs[?(@.name=="stable")].weight}' 2>/dev/null || echo "")"
CANARY_WEIGHT="$(kubectl -n "$NAMESPACE" get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs[?(@.name=="canary")].weight}' 2>/dev/null || echo "")"
ckne_log "Configured backendRefs weights: stable=${STABLE_WEIGHT:-<unset>} canary=${CANARY_WEIGHT:-<unset>}"

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

ckne_log "Sending $NUM_REQUESTS requests through the Gateway to sample the observed split"
SCRIPT_TMPL='
i=0
stable=0
canary=0
while [ "$i" -lt __NUM__ ]; do
  body=$(wget -q -T 5 -O- --header="Host: app.ckne.local" "http://__GWIP__/" 2>/dev/null)
  case "$body" in
    *stable-response*) stable=$((stable+1)) ;;
    *canary-response*) canary=$((canary+1)) ;;
  esac
  i=$((i+1))
done
echo "STABLE_COUNT=$stable"
echo "CANARY_COUNT=$canary"
'
SCRIPT="${SCRIPT_TMPL//__GWIP__/$GW_IP}"
SCRIPT="${SCRIPT//__NUM__/$NUM_REQUESTS}"

OUT="$(kubectl -n "$NAMESPACE" run "atm03-checker-$$" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
  --command -- sh -c "$SCRIPT" 2>/dev/null || true)"

STABLE_COUNT="$(printf '%s\n' "$OUT" | grep -o 'STABLE_COUNT=[0-9]*' | cut -d= -f2 || true)"
CANARY_COUNT="$(printf '%s\n' "$OUT" | grep -o 'CANARY_COUNT=[0-9]*' | cut -d= -f2 || true)"
STABLE_COUNT="${STABLE_COUNT:-0}"
CANARY_COUNT="${CANARY_COUNT:-0}"
TOTAL=$((STABLE_COUNT + CANARY_COUNT))

if [[ "$TOTAL" -lt "$MIN_SUCCESSFUL" ]]; then
  ckne_fail_check "Only $TOTAL/$NUM_REQUESTS requests got a recognizable response (need at least $MIN_SUCCESSFUL) — is the Gateway actually routing traffic?"
  echo "FAIL"
  exit 1
fi
ckne_pass "Got $TOTAL/$NUM_REQUESTS recognizable responses (stable=$STABLE_COUNT, canary=$CANARY_COUNT)"

STABLE_PCT=$((STABLE_COUNT * 100 / TOTAL))
CANARY_PCT=$((CANARY_COUNT * 100 / TOTAL))

STABLE_MIN=$((TARGET_STABLE_PCT - TOLERANCE_PCT))
STABLE_MAX=$((TARGET_STABLE_PCT + TOLERANCE_PCT))
[[ "$STABLE_MIN" -lt 0 ]] && STABLE_MIN=0
[[ "$STABLE_MAX" -gt 100 ]] && STABLE_MAX=100

CANARY_MIN=$((TARGET_CANARY_PCT - TOLERANCE_PCT))
CANARY_MAX=$((TARGET_CANARY_PCT + TOLERANCE_PCT))
[[ "$CANARY_MIN" -lt 0 ]] && CANARY_MIN=0
[[ "$CANARY_MAX" -gt 100 ]] && CANARY_MAX=100

ckne_log "Observed split: stable=${STABLE_PCT}% canary=${CANARY_PCT}% (target ${TARGET_STABLE_PCT}/${TARGET_CANARY_PCT}, tolerance +/-${TOLERANCE_PCT} percentage points — see task.md)"

if [[ "$STABLE_PCT" -ge "$STABLE_MIN" && "$STABLE_PCT" -le "$STABLE_MAX" ]]; then
  ckne_pass "Observed stable share (${STABLE_PCT}%) is within tolerance of the configured ${TARGET_STABLE_PCT}% weight"
else
  ckne_fail_check "Observed stable share (${STABLE_PCT}%) is outside the tolerance band [${STABLE_MIN}%,${STABLE_MAX}%] around the required ${TARGET_STABLE_PCT}% weight"
  RESULT=1
fi

if [[ "$CANARY_PCT" -ge "$CANARY_MIN" && "$CANARY_PCT" -le "$CANARY_MAX" ]]; then
  ckne_pass "Observed canary share (${CANARY_PCT}%) is within tolerance of the configured ${TARGET_CANARY_PCT}% weight"
else
  ckne_fail_check "Observed canary share (${CANARY_PCT}%) is outside the tolerance band [${CANARY_MIN}%,${CANARY_MAX}%] around the required ${TARGET_CANARY_PCT}% weight"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
