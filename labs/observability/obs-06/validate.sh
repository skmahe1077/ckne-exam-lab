#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-06"
NAMESPACE="ckne-obs-06"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

# Preconditions (not the task): Cilium/Hubble and Prometheus must be healthy.
CILIUM_DESIRED="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
CILIUM_READY="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$CILIUM_DESIRED" && "$CILIUM_DESIRED" != "0" && "$CILIUM_DESIRED" == "$CILIUM_READY" ]]; then
  ckne_pass "Cilium DaemonSet Ready ($CILIUM_READY/$CILIUM_DESIRED nodes) — precondition"
else
  ckne_fail_check "Cilium DaemonSet not Ready ($CILIUM_READY/$CILIUM_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

PROM_READY="$(kubectl -n monitoring get deployment prometheus-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${PROM_READY:-0}" -ge 1 ]]; then
  ckne_pass "Prometheus server Deployment Ready in monitoring — precondition"
else
  ckne_fail_check "Prometheus server Deployment not Ready in monitoring — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

BACKEND_READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${BACKEND_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is 1/1 Ready"
else
  ckne_fail_check "Deployment backend is ${BACKEND_READY:-0}/1 Ready"
  RESULT=1
fi

CLIENT_PHASE="$(kubectl -n "$NAMESPACE" get pod client -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$CLIENT_PHASE" == "Running" ]]; then
  ckne_pass "Pod client is Running"
else
  ckne_fail_check "Pod client is not Running (phase: ${CLIENT_PHASE:-<missing>})"
  RESULT=1
fi

# Read the (student-editable) client-config ConfigMap.
CLIENT_TIMEOUT_SECONDS="$(kubectl -n "$NAMESPACE" get configmap client-config -o jsonpath='{.data.CLIENT_TIMEOUT_SECONDS}' 2>/dev/null || true)"
if [[ -z "$CLIENT_TIMEOUT_SECONDS" ]]; then
  ckne_fail_check "client-config ConfigMap is missing CLIENT_TIMEOUT_SECONDS — run: make start LAB=$TASK_ID"
  echo "FAIL"
  exit 1
fi

if ! echo "$CLIENT_TIMEOUT_SECONDS" | grep -Eq '^[0-9]+$'; then
  ckne_fail_check "CLIENT_TIMEOUT_SECONDS is not a plain integer number of seconds (got: '$CLIENT_TIMEOUT_SECONDS')"
  RESULT=1
elif [[ "$CLIENT_TIMEOUT_SECONDS" -lt 4 ]]; then
  ckne_fail_check "CLIENT_TIMEOUT_SECONDS (${CLIENT_TIMEOUT_SECONDS}s) is too tight for the backend's real response time — requests keep aborting before the backend finishes"
  RESULT=1
elif [[ "$CLIENT_TIMEOUT_SECONDS" -gt 15 ]]; then
  ckne_fail_check "CLIENT_TIMEOUT_SECONDS (${CLIENT_TIMEOUT_SECONDS}s) is unreasonably large for a backend that only takes ~3s — that masks the real latency instead of giving a sane margin"
  RESULT=1
else
  ckne_pass "CLIENT_TIMEOUT_SECONDS (${CLIENT_TIMEOUT_SECONDS}s) is a reasonable value"
fi

# --- Real, timed, end-to-end request ----------------------------------------
NONCE="obs06$(date +%s)$$"
START_TS="$(date +%s)"
REQ_OK=0
if kubectl -n "$NAMESPACE" exec client -c client -- \
    wget -q -T "$CLIENT_TIMEOUT_SECONDS" -O- "http://backend.${NAMESPACE}.svc.cluster.local:8080/process?nonce=${NONCE}" >/tmp/obs06-req.out 2>&1; then
  REQ_OK=1
fi
END_TS="$(date +%s)"
ELAPSED=$(( END_TS - START_TS ))

if [[ "$REQ_OK" -eq 1 ]]; then
  ckne_pass "A real end-to-end request to backend succeeded within the configured timeout (took ${ELAPSED}s)"
else
  ckne_fail_check "A real end-to-end request to backend did NOT succeed within ${CLIENT_TIMEOUT_SECONDS}s (took ${ELAPSED}s before giving up)"
  RESULT=1
fi
rm -f /tmp/obs06-req.out

if [[ "$REQ_OK" -eq 1 && "$ELAPSED" -lt 2 ]]; then
  ckne_fail_check "The request returned in ${ELAPSED}s, faster than backend's real ~3s processing time — something looks wrong with the test setup"
  RESULT=1
fi

# Real log check: backend's own application logs must show it actually
# processed THIS request (proves the "slow" theory, not a fluke).
if kubectl -n "$NAMESPACE" logs deployment/backend --tail=200 2>/dev/null | grep -q "$NONCE"; then
  ckne_pass "backend's own logs show it processed our request (nonce=$NONCE)"
else
  ckne_fail_check "backend's logs do not show our request (nonce=$NONCE) being processed"
  RESULT=1
fi

# Real Prometheus check: the backend's self-reported latency metric must be
# genuinely scraped and non-empty (confirms the latency figure used for
# diagnosis came from real telemetry, not a guess).
FOUND_METRIC=0
for _ in $(seq 1 15); do
  PROM_OUT="$(kubectl -n "$NAMESPACE" exec client -c client -- \
    wget -q -T 5 -O- "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs06_backend_delay_seconds" 2>/dev/null || true)"
  if echo "$PROM_OUT" | grep -q '"status":"success"' && echo "$PROM_OUT" | grep -Eq '"value":\[[0-9.]+,"[0-9.]+"\]'; then
    FOUND_METRIC=1
    break
  fi
  sleep 10
done
if [[ "$FOUND_METRIC" -eq 1 ]]; then
  ckne_pass "PromQL query for obs06_backend_delay_seconds returns real, non-empty data"
else
  ckne_fail_check "PromQL query for obs06_backend_delay_seconds never returned real data — Prometheus is not scraping backend"
  RESULT=1
fi

# Real Hubble check: a healthy FORWARDED flow between client and backend
# must be observable at the network layer once requests are actually
# succeeding (loop over every cilium agent Pod — each only sees flows local
# to its own node).
CILIUM_PODS="$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
FOUND_FLOW=0
for pod in $CILIUM_PODS; do
  OUT="$(kubectl -n kube-system exec "$pod" -c cilium-agent -- hubble observe --namespace "$NAMESPACE" --last 200 2>/dev/null || \
         kubectl -n kube-system exec "$pod" -- hubble observe --namespace "$NAMESPACE" --last 200 2>/dev/null || true)"
  if echo "$OUT" | grep "client" | grep -q "FORWARDED"; then
    FOUND_FLOW=1
    break
  fi
done
if [[ "$FOUND_FLOW" -eq 1 ]]; then
  ckne_pass "Hubble shows a FORWARDED flow between client and backend (healthy end-to-end network path)"
else
  ckne_fail_check "Hubble shows no FORWARDED flow between client and backend"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
