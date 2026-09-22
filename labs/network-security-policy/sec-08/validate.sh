#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-08"
NAMESPACE="ckne-sec-08"
LOCK_RESOURCE="cilium-config"

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

READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is Ready"
else
  ckne_fail_check "Deployment backend is not Ready (${READY:-0}/1) — this is a precondition, fix the environment first"
  RESULT=1
fi

URL="http://backend.${NAMESPACE}.svc.cluster.local"

# --- Part A: L7 CiliumNetworkPolicy ---

CODE="$(kubectl -n "$NAMESPACE" exec caller -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X GET "${URL}/health" 2>/dev/null || echo 000)"
if [[ "$CODE" == "200" ]]; then
  ckne_pass "caller: GET /health succeeds (HTTP 200)"
else
  ckne_fail_check "caller: GET /health did not succeed (got HTTP $CODE) — this should be explicitly allowed"
  RESULT=1
fi

CODE="$(kubectl -n "$NAMESPACE" exec caller -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST "${URL}/admin" 2>/dev/null || echo 000)"
if [[ "$CODE" == "200" ]]; then
  ckne_fail_check "caller: POST /admin succeeded (HTTP 200) — the CiliumNetworkPolicy's L7 http rule must reject anything other than GET /health"
  RESULT=1
else
  ckne_pass "caller: POST /admin is correctly rejected (got HTTP $CODE)"
fi

CODE="$(kubectl -n "$NAMESPACE" exec outsider -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X GET "${URL}/health" 2>/dev/null || echo 000)"
if [[ "$CODE" == "200" ]]; then
  ckne_fail_check "outsider: reached backend (HTTP 200) — only Pods labeled app=caller may reach backend at all"
  RESULT=1
else
  ckne_pass "outsider: correctly cannot reach backend (got HTTP $CODE)"
fi

# --- Part B: Transparent Encryption (WireGuard) ---

CILIUM_DESIRED="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
CILIUM_READY="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$CILIUM_DESIRED" && "$CILIUM_DESIRED" != "0" && "$CILIUM_DESIRED" == "$CILIUM_READY" ]]; then
  ckne_pass "Cilium DaemonSet is Ready on every node ($CILIUM_READY/$CILIUM_DESIRED) after enabling encryption"
else
  ckne_fail_check "Cilium DaemonSet not Ready ($CILIUM_READY/$CILIUM_DESIRED) after the Helm change"
  RESULT=1
fi

WG_CM="$(kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}' 2>/dev/null || echo "")"
if [[ "$WG_CM" == "true" ]]; then
  ckne_pass "cilium-config ConfigMap reports enable-wireguard=true"
else
  ckne_fail_check "cilium-config ConfigMap does not report enable-wireguard=true (got: '${WG_CM:-<unset>}') — enable it via: helm upgrade cilium cilium/cilium --reuse-values --set encryption.enabled=true --set encryption.type=wireguard -n kube-system --wait"
  RESULT=1
fi

CILIUM_POD="$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "$CILIUM_POD" ]]; then
  STATUS_OUT="$(kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium-dbg status --brief 2>/dev/null || true)"
  if [[ -z "$STATUS_OUT" ]]; then
    STATUS_OUT="$(kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium status --brief 2>/dev/null || true)"
  fi
  if printf '%s' "$STATUS_OUT" | grep -qi "wireguard"; then
    ckne_pass "Live Cilium agent ($CILIUM_POD) reports WireGuard encryption active"
  else
    ckne_fail_check "Live Cilium agent ($CILIUM_POD) status does not report WireGuard as active"
    printf '%s\n' "$STATUS_OUT" >&2
    RESULT=1
  fi
else
  ckne_fail_check "Could not find a running Cilium agent Pod in kube-system to check live status"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
