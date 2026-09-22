#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-08"
NAMESPACE="ckne-atm-08"
GATEWAY_NAME="atm-08-gw"
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
  echo "FAIL"
  exit 1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment streaming-echo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment streaming-echo is Ready"
else
  ckne_fail_check "Deployment streaming-echo is not Ready (${READY:-0}/1)"
  RESULT=1
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

# --- Real runtime check #1: the /slow rule's request timeout must actually
# be enforced. The backend sleeps 8s before responding with zero bytes in
# between; if a request timeout is correctly configured on this rule, the
# Gateway must cut the request off well before 8s. Duration close to 8s
# means no effective timeout is enforced; duration well under it means one
# is. (The checker's own wget -T 12 is only a safety net so this never hangs
# indefinitely if no timeout is enforced at all.)
CMD_TIMEOUT="START=\$(date +%s); wget -q -T 12 -O- \"http://${GW_IP}/slow?delay=8\" >/tmp/o 2>/tmp/e; RC=\$?; END=\$(date +%s); echo \"RC=\$RC DUR=\$((END-START))\""
TIMEOUT_OUT=""
for attempt in 1 2 3; do
  TIMEOUT_OUT="$(kubectl -n "$NAMESPACE" run "atm08-timeout-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
    --command -- sh -c "$CMD_TIMEOUT" 2>/dev/null || true)"
  printf '%s' "$TIMEOUT_OUT" | grep -q "DUR=" && break
  sleep 3
done
TIMEOUT_DUR="$(printf '%s' "$TIMEOUT_OUT" | grep -o 'DUR=[0-9]*' | head -n1 | cut -d= -f2)"

if [[ -n "${TIMEOUT_DUR:-}" && "$TIMEOUT_DUR" -le 6 ]]; then
  ckne_pass "Request to /slow (8s backend delay) was cut off at ~${TIMEOUT_DUR}s — a request timeout is actively enforced on that rule"
else
  ckne_fail_check "Request to /slow was not cut off before the backend's full 8s delay (observed: ${TIMEOUT_DUR:-no result}s) — no effective request timeout is enforced on that rule"
  RESULT=1
fi

# --- Real runtime check #2: /stream must deliver its chunks incrementally
# (5 chunks x 1s delay = ~5s total), not be buffered server/proxy-side and
# returned all at once. A duration close to ~5s (not near-zero) is the proof
# it was actually streamed; the body must also contain the final chunk,
# proving the full sequence arrived rather than being cut off.
CMD_STREAM="START=\$(date +%s); wget -q -T 20 -O- \"http://${GW_IP}/stream?chunks=5&delay=1\" >/tmp/o 2>/tmp/e; RC=\$?; END=\$(date +%s); echo \"RC=\$RC DUR=\$((END-START))\"; cat /tmp/o"
STREAM_OUT=""
for attempt in 1 2 3; do
  STREAM_OUT="$(kubectl -n "$NAMESPACE" run "atm08-stream-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
    --command -- sh -c "$CMD_STREAM" 2>/dev/null || true)"
  printf '%s' "$STREAM_OUT" | grep -q "DUR=" && break
  sleep 3
done
STREAM_DUR="$(printf '%s' "$STREAM_OUT" | grep -o 'DUR=[0-9]*' | head -n1 | cut -d= -f2)"

if [[ -n "${STREAM_DUR:-}" && "$STREAM_DUR" -ge 4 ]] && printf '%s' "$STREAM_OUT" | grep -q "chunk-4"; then
  ckne_pass "Request to /stream took ~${STREAM_DUR}s (close to the real 5x1s chunk schedule) and delivered all 5 chunks — the response was streamed, not buffered"
else
  ckne_fail_check "Request to /stream did not behave like a streamed response (duration: ${STREAM_DUR:-no result}s, expected close to 5s and >=4s; all chunks received: $(printf '%s' "$STREAM_OUT" | grep -q "chunk-4" && echo yes || echo no))"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
