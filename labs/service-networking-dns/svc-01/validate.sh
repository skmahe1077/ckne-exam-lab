#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-01"
NAMESPACE="ckne-svc-01"

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

READY="$(kubectl -n "$NAMESPACE" get deployment api -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "2" ]]; then
  ckne_pass "Deployment api is 2/2 Ready"
else
  ckne_fail_check "Deployment api is ${READY:-0}/2 Ready"
  RESULT=1
fi

EP_IPS="$(kubectl -n "$NAMESPACE" get endpoints api -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
EP_COUNT=0
for ip in $EP_IPS; do
  EP_COUNT=$((EP_COUNT + 1))
done
if [[ "$EP_COUNT" -eq 2 ]]; then
  ckne_pass "Service api has 2 healthy Endpoints ($EP_IPS)"
else
  ckne_fail_check "Service api has $EP_COUNT Endpoints, expected 2 — selector likely does not match Pod labels"
  RESULT=1
fi

# Real runtime behaviour check: actually send traffic through the Service.
if kubectl -n "$NAMESPACE" run svc01-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://api.${NAMESPACE}.svc.cluster.local" >/tmp/svc01-checker.out 2>&1; then
  ckne_pass "Service api routes traffic successfully"
else
  ckne_fail_check "Service api did not respond to an in-cluster request"
  cat /tmp/svc01-checker.out >&2 || true
  RESULT=1
fi
rm -f /tmp/svc01-checker.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
