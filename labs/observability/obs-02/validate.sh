#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-02"
NAMESPACE="ckne-obs-02"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0

ckne_require_kubectl

# Precondition (not the task): CoreDNS itself must be healthy cluster-wide.
COREDNS_READY="$(kubectl -n kube-system get deployment coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
COREDNS_DESIRED="$(kubectl -n kube-system get deployment coredns -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
if [[ -n "$COREDNS_DESIRED" && "$COREDNS_DESIRED" != "0" && "$COREDNS_DESIRED" == "$COREDNS_READY" ]]; then
  ckne_pass "CoreDNS Deployment Ready ($COREDNS_READY/$COREDNS_DESIRED) — cluster-level precondition"
else
  ckne_fail_check "CoreDNS Deployment not Ready ($COREDNS_READY/$COREDNS_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment orders -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "2" ]]; then
  ckne_pass "Deployment orders is 2/2 Ready"
else
  ckne_fail_check "Deployment orders is ${READY:-0}/2 Ready"
  RESULT=1
fi

EP_IPS="$(kubectl -n "$NAMESPACE" get endpoints orders -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
EP_COUNT=0
for ip in $EP_IPS; do
  EP_COUNT=$((EP_COUNT + 1))
done
if [[ "$EP_COUNT" -eq 2 ]]; then
  ckne_pass "Service orders has 2 healthy Endpoints ($EP_IPS)"
else
  ckne_fail_check "Service orders has $EP_COUNT Endpoints, expected 2 — Pods are likely still failing readiness"
  RESULT=1
fi

# Real runtime behaviour check: DNS resolution of the Service name works
# (proves CoreDNS was never the actual problem) AND traffic actually routes.
DNS_OUT="$(kubectl -n "$NAMESPACE" run obs02-dns-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- nslookup "orders.${NAMESPACE}.svc.cluster.local" 2>&1 || true)"
if echo "$DNS_OUT" | grep -q "Address"; then
  ckne_pass "DNS resolution of orders.${NAMESPACE}.svc.cluster.local succeeds (CoreDNS was never the problem)"
else
  ckne_fail_check "DNS resolution of orders.${NAMESPACE}.svc.cluster.local failed"
  echo "$DNS_OUT" >&2
  RESULT=1
fi

if kubectl -n "$NAMESPACE" run obs02-http-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://orders.${NAMESPACE}.svc.cluster.local" >/tmp/obs02-checker.out 2>&1; then
  ckne_pass "Service orders routes traffic successfully"
else
  ckne_fail_check "Service orders did not respond to an in-cluster request"
  cat /tmp/obs02-checker.out >&2 || true
  RESULT=1
fi
rm -f /tmp/obs02-checker.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
