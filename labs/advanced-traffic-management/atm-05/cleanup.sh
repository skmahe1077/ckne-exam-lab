#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-05"
NAMESPACE="ckne-atm-05"
EGRESS_NODE_LABEL="ckne.openai.com/atm-05-egress-node"
POLICY_NAME="ckne-atm-05-egress-policy"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

ckne_log "Deleting cluster-scoped CiliumEgressGatewayPolicy $POLICY_NAME"
kubectl delete ciliumegressgatewaypolicy "$POLICY_NAME" --ignore-not-found --wait=true --timeout=60s

ckne_log "Reverting Cilium's egress gateway feature (egressGateway.enabled=false) — restoring the well-known original value"
if helm status cilium -n kube-system >/dev/null 2>&1; then
  helm upgrade cilium cilium/cilium --reuse-values --set egressGateway.enabled=false \
    --namespace kube-system --wait --timeout 5m
  kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
else
  ckne_warn "Cilium Helm release not found in kube-system — skipping egressGateway revert (nothing to revert)"
fi

ckne_log "Removing this lab's egress-gateway node label ($EGRESS_NODE_LABEL)"
LABELED_NODES="$(kubectl get nodes -l "${EGRESS_NODE_LABEL}=true" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
for node in $LABELED_NODES; do
  kubectl label node "$node" "${EGRESS_NODE_LABEL}-" >/dev/null
done

ckne_log "Releasing shared-resource lock 'cilium-config'"
"$REPO_ROOT/shared/scripts/lock.sh" release cilium-config "$TASK_ID"

ckne_log "Deleting namespace $NAMESPACE"
ckne_delete_namespace "$NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE"; then
  ckne_log "Namespace $NAMESPACE gone."
else
  ckne_fail "Namespace $NAMESPACE still exists after cleanup"
fi

if kubectl get ciliumegressgatewaypolicy "$POLICY_NAME" >/dev/null 2>&1; then
  ckne_fail "CiliumEgressGatewayPolicy $POLICY_NAME still exists after cleanup"
fi

REMAINING_LABELED="$(kubectl get nodes -l "${EGRESS_NODE_LABEL}=true" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${REMAINING_LABELED:-0}" != "0" ]]; then
  ckne_fail "Node label $EGRESS_NODE_LABEL=true still present on ${REMAINING_LABELED} node(s) after cleanup"
fi

ckne_log "Cleanup verified: CiliumEgressGatewayPolicy removed, node label removed, egressGateway reverted, lock released, namespace gone."
exit 0
