#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-03"
NAMESPACE="ckne-svc-03"

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

if ! kubectl -n "$NAMESPACE" get svc shop >/dev/null 2>&1; then
  ckne_fail_check "Service shop does not exist in $NAMESPACE — it must be created for this task"
  echo "FAIL"
  exit 1
fi

SVC_TYPE="$(kubectl -n "$NAMESPACE" get svc shop -o jsonpath='{.spec.type}' 2>/dev/null || true)"
if [[ "$SVC_TYPE" == "LoadBalancer" ]]; then
  ckne_pass "Service shop is type LoadBalancer"
else
  ckne_fail_check "Service shop has type '$SVC_TYPE', expected LoadBalancer"
  RESULT=1
fi

CLUSTER_IP="$(kubectl -n "$NAMESPACE" get svc shop -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
if [[ -n "$CLUSTER_IP" && "$CLUSTER_IP" != "None" ]]; then
  ckne_pass "Service shop has a valid ClusterIP ($CLUSTER_IP)"
else
  ckne_fail_check "Service shop has no valid ClusterIP"
  RESULT=1
fi

EP_IPS="$(kubectl -n "$NAMESPACE" get endpoints shop -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
EP_COUNT=0
for ip in $EP_IPS; do
  EP_COUNT=$((EP_COUNT + 1))
done
if [[ "$EP_COUNT" -eq 2 ]]; then
  ckne_pass "Service shop has 2 healthy Endpoints ($EP_IPS)"
else
  ckne_fail_check "Service shop has $EP_COUNT Endpoints, expected 2 — check the selector"
  RESULT=1
fi

# Expected behaviour on this cluster: no cloud-controller-manager / MetalLB
# is running, so status.loadBalancer.ingress must stay empty. That is the
# CORRECT state, not a failure.
LB_INGRESS="$(kubectl -n "$NAMESPACE" get svc shop -o jsonpath='{.status.loadBalancer.ingress}' 2>/dev/null || true)"
if [[ -z "$LB_INGRESS" ]]; then
  ckne_pass "status.loadBalancer.ingress is empty (EXTERNAL-IP Pending is expected — no LB controller in this cluster)"
else
  ckne_fail_check "status.loadBalancer.ingress is unexpectedly populated ($LB_INGRESS) — no LB controller should exist in this cluster"
  RESULT=1
fi

# Real runtime behaviour check: the Service must still route traffic via
# its ClusterIP even though it will never get an external IP here.
if kubectl -n "$NAMESPACE" run svc03-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://shop.${NAMESPACE}.svc.cluster.local" >/tmp/svc03-checker.out 2>&1; then
  ckne_pass "Service shop routes traffic successfully via its ClusterIP"
else
  ckne_fail_check "Service shop did not respond to an in-cluster request via its ClusterIP"
  cat /tmp/svc03-checker.out >&2 || true
  RESULT=1
fi
rm -f /tmp/svc03-checker.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
