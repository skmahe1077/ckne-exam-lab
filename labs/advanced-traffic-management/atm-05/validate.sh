#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-05"
NAMESPACE="ckne-atm-05"
POLICY_NAME="ckne-atm-05-egress-policy"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0
ckne_require_kubectl

# Precondition (not the task): Cilium itself must be healthy cluster-wide.
CILIUM_DESIRED="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
CILIUM_READY="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$CILIUM_DESIRED" && "$CILIUM_DESIRED" != "0" && "$CILIUM_DESIRED" == "$CILIUM_READY" ]]; then
  ckne_pass "Cilium DaemonSet Ready ($CILIUM_READY/$CILIUM_DESIRED nodes)"
else
  ckne_fail_check "Cilium DaemonSet not Ready ($CILIUM_READY/$CILIUM_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

# Precondition (established by setup.sh via the 'cilium-config' lock, not the
# task itself): the egress gateway feature must be enabled cluster-wide.
EGW_ENABLED="$(kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-egress-gateway}' 2>/dev/null || echo "")"
if [[ "$EGW_ENABLED" == "true" ]]; then
  ckne_pass "Cilium reports the egress gateway feature enabled (cilium-config: enable-egress-gateway=true)"
else
  ckne_fail_check "cilium-config ConfigMap does not report enable-egress-gateway=true — run: make start LAB=$TASK_ID"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  echo "FAIL"
  exit 1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment egress-client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment egress-client is Ready"
else
  ckne_fail_check "Deployment egress-client is not Ready (${READY:-0}/1)"
  RESULT=1
fi

if ! kubectl get ciliumegressgatewaypolicy "$POLICY_NAME" >/dev/null 2>&1; then
  ckne_fail_check "CiliumEgressGatewayPolicy $POLICY_NAME does not exist — run: make start LAB=$TASK_ID"
  echo "FAIL"
  exit 1
fi

CLIENT_POD_IP="$(kubectl -n "$NAMESPACE" get pods -l app=egress-client -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")"

# Real runtime behaviour: ask a live Cilium agent what its datapath actually
# programmed for this policy. Reading kube-system here is a deliberate,
# in-scope exception to the "labs only read kube-system" rule — this lab's
# task IS reconfiguring a cluster-scoped CiliumEgressGatewayPolicy, and the
# agent's egress map is the only place that reflects whether the policy's
# selectors actually resolved to a real Pod. This is the same command Cilium's
# own egress-gateway troubleshooting docs use to verify the feature.
EGRESS_LIST=""
for _ in $(seq 1 10); do
  EGRESS_LIST="$(kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list 2>/dev/null || true)"
  if [[ -n "$CLIENT_POD_IP" ]] && printf '%s' "$EGRESS_LIST" | grep -q "$CLIENT_POD_IP"; then
    break
  fi
  sleep 3
done

if [[ -n "$CLIENT_POD_IP" ]] \
    && printf '%s' "$EGRESS_LIST" | grep "$CLIENT_POD_IP" | grep -q "1.1.1.1/32"; then
  ckne_pass "Cilium's datapath (cilium-dbg bpf egress list) shows egress-client's Pod ($CLIENT_POD_IP) mapped to destination 1.1.1.1/32 through the designated gateway node"
else
  ckne_fail_check "Cilium's datapath shows no egress mapping for egress-client's Pod ($CLIENT_POD_IP) to 1.1.1.1/32 — the policy's selectors do not currently resolve to this Pod"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
