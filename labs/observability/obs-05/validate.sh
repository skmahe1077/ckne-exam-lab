#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-05"
NAMESPACE="ckne-obs-05"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

# Preconditions (not the task): istiod and Jaeger must be healthy cluster-wide.
ISTIOD_READY="$(kubectl -n istio-system get deployment istiod -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${ISTIOD_READY:-0}" -ge 1 ]]; then
  ckne_pass "istiod Deployment Ready in istio-system — precondition"
else
  ckne_fail_check "istiod Deployment not Ready in istio-system — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

JAEGER_DEPLOY="$(kubectl -n observability get deployment -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "$JAEGER_DEPLOY" ]] && kubectl -n observability get deployment "$JAEGER_DEPLOY" -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q '^[1-9]'; then
  ckne_pass "Jaeger Deployment ($JAEGER_DEPLOY) Ready in observability — precondition"
else
  ckne_fail_check "Jaeger Deployment not Ready in observability — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

INJECTION_LABEL="$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || true)"
if [[ "$INJECTION_LABEL" == "enabled" ]]; then
  ckne_pass "$NAMESPACE carries istio-injection=enabled — precondition"
else
  ckne_fail_check "$NAMESPACE is missing istio-injection=enabled — this is a precondition, do not remove it"
  RESULT=1
fi

BACKEND_READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${BACKEND_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is 1/1 Ready"
else
  ckne_fail_check "Deployment backend is ${BACKEND_READY:-0}/1 Ready"
  RESULT=1
fi

BACKEND_CONTAINERS="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null || true)"
if echo "$BACKEND_CONTAINERS" | grep -q "istio-proxy"; then
  ckne_pass "backend has an istio-proxy sidecar"
else
  ckne_fail_check "backend has no istio-proxy sidecar (containers: $BACKEND_CONTAINERS)"
  RESULT=1
fi

CLIENT_CONTAINERS="$(kubectl -n "$NAMESPACE" get pod client -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"
if echo "$CLIENT_CONTAINERS" | grep -q "istio-proxy"; then
  ckne_pass "client has an istio-proxy sidecar"
else
  ckne_fail_check "client has no istio-proxy sidecar (containers: $CLIENT_CONTAINERS)"
  RESULT=1
fi

# Read the (student-editable) trace-reporter-config ConfigMap.
CM_GET() { kubectl -n "$NAMESPACE" get configmap trace-reporter-config -o jsonpath="{.data.$1}" 2>/dev/null || true; }
JAEGER_QUERY_SVC="$(CM_GET JAEGER_QUERY_SVC)"
JAEGER_QUERY_PORT="$(CM_GET JAEGER_QUERY_PORT)"
JAEGER_COLLECTOR_SVC="$(CM_GET JAEGER_COLLECTOR_SVC)"
JAEGER_COLLECTOR_PORT="$(CM_GET JAEGER_COLLECTOR_PORT)"
if [[ -z "$JAEGER_QUERY_SVC" || -z "$JAEGER_COLLECTOR_SVC" || -z "$JAEGER_QUERY_PORT" || -z "$JAEGER_COLLECTOR_PORT" ]]; then
  ckne_fail_check "trace-reporter-config ConfigMap is missing expected keys — run: make start LAB=$TASK_ID"
  echo "FAIL"
  exit 1
fi

# --- Real runtime check #1: Envoy access logs -------------------------------
NONCE1="obs05chk$(date +%s)$$"
kubectl -n "$NAMESPACE" exec client -c client -- \
  wget -q -T 5 -O- "http://backend.${NAMESPACE}.svc.cluster.local/${NONCE1}" >/dev/null 2>&1 || true
sleep 3

FOUND_LOG=0
for _ in $(seq 1 10); do
  if kubectl -n "$NAMESPACE" logs deployment/backend -c istio-proxy --tail=500 2>/dev/null | grep -q "$NONCE1"; then
    FOUND_LOG=1
    break
  fi
  sleep 3
done
if [[ "$FOUND_LOG" -eq 1 ]]; then
  ckne_pass "Envoy access log line for the real request (/$NONCE1) is present in backend's istio-proxy logs"
else
  ckne_fail_check "No Envoy access log line for /$NONCE1 found in backend's istio-proxy logs — access logging is not enabled correctly"
  RESULT=1
fi

# --- Real runtime check #2: a real trace, submitted and queried back from Jaeger's API ---
NONCE2="obs05trace$(date +%s)$$"
TRACE_ID="$(printf '%032x' "$$")"
SPAN_ID="$(printf '%016x' "$(date +%s)")"
TS_MICROS="$(( $(date +%s) * 1000000 ))"
SPAN_JSON="[{\"id\":\"${SPAN_ID}\",\"traceId\":\"${TRACE_ID}\",\"name\":\"obs05-check\",\"timestamp\":${TS_MICROS},\"duration\":1000,\"localEndpoint\":{\"serviceName\":\"obs05-client\"},\"tags\":{\"nonce\":\"${NONCE2}\"}}]"

COLLECTOR_URL="http://${JAEGER_COLLECTOR_SVC}.observability.svc.cluster.local:${JAEGER_COLLECTOR_PORT}/api/v2/spans"
if SUBMIT_OUT="$(kubectl -n "$NAMESPACE" exec client -c client -- \
  wget -q -T 5 -O- --header="Content-Type: application/json" \
  "--post-data=${SPAN_JSON}" \
  "$COLLECTOR_URL" 2>&1)"; then
  ckne_pass "Submitted a real span to Jaeger's collector ($COLLECTOR_URL)"
else
  ckne_fail_check "Could not submit a span to Jaeger's collector at $COLLECTOR_URL (output: $SUBMIT_OUT) — check JAEGER_COLLECTOR_PORT in the trace-reporter-config ConfigMap"
  RESULT=1
fi

FOUND_TRACE=0
for _ in $(seq 1 10); do
  QUERY_OUT="$(kubectl -n "$NAMESPACE" exec client -c client -- \
    wget -q -T 5 -O- "http://${JAEGER_QUERY_SVC}.observability.svc.cluster.local:${JAEGER_QUERY_PORT}/api/traces?service=obs05-client&lookback=1h&limit=20" 2>/dev/null || true)"
  if echo "$QUERY_OUT" | grep -q "$NONCE2"; then
    FOUND_TRACE=1
    break
  fi
  sleep 5
done
if [[ "$FOUND_TRACE" -eq 1 ]]; then
  ckne_pass "Jaeger's Query API returns a real trace containing our nonce ($NONCE2) — the trace is genuinely queryable"
else
  ckne_fail_check "Jaeger's Query API never returned a trace containing our nonce ($NONCE2)"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
