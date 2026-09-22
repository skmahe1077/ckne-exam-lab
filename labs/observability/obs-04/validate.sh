#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-04"
NAMESPACE="ckne-obs-04"
CHECKER_IMAGE="busybox:1.36"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

# Precondition (not the task): the shared Prometheus server must be healthy.
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

READY="$(kubectl -n "$NAMESPACE" get deployment netmetrics -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment netmetrics is 1/1 Ready"
else
  ckne_fail_check "Deployment netmetrics is ${READY:-0}/1 Ready"
  RESULT=1
fi

# promql <description> <query> <require-nonzero: 0|1>
# Runs a throwaway checker Pod that curls Prometheus's HTTP API directly and
# checks for a real, non-empty result. Retries with backoff since Prometheus
# only scrapes targets periodically (not instantly) and target discovery
# itself takes a scrape-interval or two after a Service annotation changes.
promql() {
  local desc="$1" query="$2" require_nonzero="$3"
  local attempt out
  for attempt in $(seq 1 20); do
    out="$(kubectl -n "$NAMESPACE" run "obs04-promql-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
      --command -- wget -q -T 5 -O- "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=${query}" 2>/dev/null || true)"
    if echo "$out" | grep -q '"status":"success"' && echo "$out" | grep -q '"result":\['; then
      if echo "$out" | grep -q '"result":\[\]'; then
        : # empty result set, keep retrying
      else
        if [[ "$require_nonzero" == "1" ]]; then
          if echo "$out" | grep -Eq '"value":\[[0-9.]+,"[1-9][0-9]*(\.[0-9]+)?"\]'; then
            ckne_pass "$desc"
            return 0
          fi
        else
          ckne_pass "$desc"
          return 0
        fi
      fi
    fi
    sleep 10
  done
  ckne_fail_check "$desc (PromQL query '$query' did not return a real, non-empty result in time)"
  return 1
}

# Real traffic: generate 3 hits against netmetrics through its own Service
# (this uses the Service's real port/targetPort, which are correct — only
# the Prometheus scrape annotation is broken).
HITS_OK=0
for i in 1 2 3; do
  if kubectl -n "$NAMESPACE" run "obs04-hit-$$-$i" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
      --command -- wget -q -T 5 -O- "http://netmetrics.${NAMESPACE}.svc.cluster.local:8080/hit" >/dev/null 2>&1; then
    HITS_OK=$((HITS_OK + 1))
  fi
done
if [[ "$HITS_OK" -eq 3 ]]; then
  ckne_pass "Generated 3/3 real requests to netmetrics /hit (Service traffic itself works)"
else
  ckne_fail_check "Only $HITS_OK/3 requests to netmetrics /hit succeeded — the Service itself is not routing correctly"
  RESULT=1
fi

# Real observability check #1: a built-in, always-scraped network-relevant
# metric (the API server's request counter) must be queryable and flowing —
# proves Prometheus itself is scraping real cluster network components, not
# just "the Pod is Running".
promql "PromQL query for apiserver_request_total returns real, non-empty data (core network component metrics are flowing)" \
  "apiserver_request_total" "1" || RESULT=1

# Real observability check #2: the task-specific metric. Only appears once
# the netmetrics Service's prometheus.io/port annotation is fixed to 8080.
promql "PromQL query for obs04_requests_total returns real, non-empty, non-zero data (netmetrics is being scraped)" \
  "obs04_requests_total" "1" || RESULT=1

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
