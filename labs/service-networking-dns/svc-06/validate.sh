#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-06"
NAMESPACE="ckne-svc-06"

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

READY="$(kubectl -n "$NAMESPACE" get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
DESIRED="$(kubectl -n "$NAMESPACE" get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "2" && "$DESIRED" == "2" ]]; then
  ckne_pass "Deployment web is 2/2 Ready"
else
  ckne_fail_check "Deployment web is ${READY:-0}/${DESIRED:-2} Ready"
  RESULT=1
fi

# Inspect the actual EndpointSlice object(s) for the Service — every listed
# endpoint must be conditions.ready == true, and there must be exactly 2 of
# them (matching the 2 desired replicas).
READY_FLAGS="$(kubectl -n "$NAMESPACE" get endpointslice -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*]}{range .endpoints[*]}{.conditions.ready}{"\n"}{end}{end}' 2>/dev/null || true)"

TOTAL_EPS=0
READY_EPS=0
for flag in $READY_FLAGS; do
  TOTAL_EPS=$((TOTAL_EPS + 1))
  [[ "$flag" == "true" ]] && READY_EPS=$((READY_EPS + 1))
done

if [[ "$TOTAL_EPS" -eq 2 && "$READY_EPS" -eq 2 ]]; then
  ckne_pass "EndpointSlice for Service web lists $READY_EPS/$TOTAL_EPS endpoints as ready:true"
else
  ckne_fail_check "EndpointSlice for Service web shows $READY_EPS ready out of $TOTAL_EPS listed endpoints (expected 2/2) — check: kubectl get endpointslice -n $NAMESPACE -l kubernetes.io/service-name=web -o yaml"
  RESULT=1
fi

# Real runtime behaviour check: actually send traffic through the Service.
if kubectl -n "$NAMESPACE" run svc06-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://web.${NAMESPACE}.svc.cluster.local" >/tmp/svc06-checker.out 2>&1; then
  ckne_pass "Service web routes traffic successfully end-to-end"
else
  ckne_fail_check "Service web did not respond to an in-cluster request"
  cat /tmp/svc06-checker.out >&2 || true
  RESULT=1
fi
rm -f /tmp/svc06-checker.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
