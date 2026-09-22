#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-08"
NAMESPACE="ckne-svc-08"

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

# Precondition: the base cluster.local handling must still be intact — we
# only ever want an ADDITIVE change, never a replacement of the whole Corefile.
COREFILE="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' 2>/dev/null || echo "")"
if printf '%s' "$COREFILE" | grep -q 'kubernetes cluster.local'; then
  ckne_pass "kube-system/coredns Corefile still contains the original cluster.local handling"
else
  ckne_fail_check "kube-system/coredns Corefile no longer contains the original cluster.local handling — this is a cluster-wide breakage, fix immediately"
  RESULT=1
fi

kubectl -n "$NAMESPACE" delete pod svc08-checker --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
kubectl -n "$NAMESPACE" run svc08-checker --image=busybox:1.36 --restart=Never -- sleep 300 >/dev/null
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/svc08-checker --timeout=60s >/dev/null

# Real runtime behaviour: the scoped forward must actually resolve correctly.
LOOKUP_OUT="$(kubectl -n "$NAMESPACE" exec svc08-checker -- nslookup check.svc08test.example 2>&1 || true)"
if printf '%s' "$LOOKUP_OUT" | grep -q '10\.99\.99\.99'; then
  ckne_pass "check.svc08test.example resolves to 10.99.99.99"
else
  ckne_fail_check "check.svc08test.example did not resolve to 10.99.99.99"
  printf '%s\n' "$LOOKUP_OUT" >&2
  RESULT=1
fi

# Real runtime behaviour: normal cluster DNS must still work for everyone else.
if kubectl -n "$NAMESPACE" exec svc08-checker -- nslookup kubernetes.default.svc.cluster.local >/tmp/svc08-k8s.out 2>&1; then
  ckne_pass "kubernetes.default.svc.cluster.local still resolves (cluster DNS is not broken)"
else
  ckne_fail_check "kubernetes.default.svc.cluster.local FAILED to resolve — cluster DNS is broken for everyone"
  cat /tmp/svc08-k8s.out >&2 || true
  RESULT=1
fi
rm -f /tmp/svc08-k8s.out

kubectl -n "$NAMESPACE" delete pod svc08-checker --ignore-not-found --wait=false >/dev/null 2>&1 || true

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
