#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-06"
NAMESPACE="ckne-cni-06"

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

READY="$(kubectl -n "$NAMESPACE" get deployment multi-iface-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment multi-iface-app is Ready (both containers)"
else
  ckne_fail_check "Deployment multi-iface-app is not Ready (${READY:-0}/1) — this is a precondition, fix the environment first"
  RESULT=1
fi

IP_COUNT="$(kubectl -n "$NAMESPACE" get pods -l app=multi-iface-app -o jsonpath='{.items[0].status.podIPs}' 2>/dev/null | grep -o '"ip"' | wc -l | tr -d ' ')"
if [[ "${IP_COUNT:-0}" == "1" ]]; then
  ckne_pass "multi-iface-app Pod has exactly one real podIP (single interface, as expected without Multus)"
else
  ckne_fail_check "multi-iface-app Pod does not report exactly one podIP (got count: ${IP_COUNT:-0})"
  RESULT=1
fi

run_check() {
  local pod="$1" ns="$2" url="$3" expect_body="$4" label="$5"
  local out
  if out="$(kubectl -n "$ns" exec "$pod" -- wget -q -T 5 -O- "$url" 2>&1)"; then
    if [[ -n "$expect_body" ]] && ! printf '%s' "$out" | grep -q "$expect_body"; then
      ckne_fail_check "$label: request succeeded but did not return expected content"
      return 1
    fi
    ckne_pass "$label"
    return 0
  else
    ckne_fail_check "$label: request did not succeed"
    return 1
  fi
}

DATA_URL="http://data-svc.${NAMESPACE}.svc.cluster.local:8080"
MGMT_URL="http://mgmt-svc.${NAMESPACE}.svc.cluster.local:9090"

run_check client "$NAMESPACE" "$DATA_URL" "data-plane" \
  "client (no special label) can reach data-svc:8080" || RESULT=1

if kubectl -n "$NAMESPACE" exec client -- wget -q -T 5 -O- "$MGMT_URL" >/tmp/cni06-blocked.out 2>&1; then
  ckne_fail_check "client reached mgmt-svc:9090 — the management plane must be restricted to role=admin Pods"
  RESULT=1
else
  ckne_pass "client is correctly blocked from mgmt-svc:9090"
fi
rm -f /tmp/cni06-blocked.out

run_check admin-client "$NAMESPACE" "$MGMT_URL" "mgmt-plane" \
  "admin-client (role=admin) can reach mgmt-svc:9090" || RESULT=1

run_check admin-client "$NAMESPACE" "$DATA_URL" "data-plane" \
  "admin-client can also reach data-svc:8080" || RESULT=1

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
