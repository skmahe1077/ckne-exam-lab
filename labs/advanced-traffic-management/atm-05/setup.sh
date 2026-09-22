#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-05"
NAMESPACE="ckne-atm-05"
EGRESS_NODE_LABEL="ckne.openai.com/atm-05-egress-node"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

WORKER_COUNT="$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${WORKER_COUNT:-0}" -lt 2 ]]; then
  ckne_fail "Expected at least 2 worker nodes (this lab dedicates one as the egress gateway and schedules the client on another), found ${WORKER_COUNT:-0}."
fi

ckne_log "Acquiring shared-resource lock 'cilium-config' (this lab mutates the cluster-wide Cilium Helm release)"
"$REPO_ROOT/shared/scripts/lock.sh" acquire cilium-config "$TASK_ID"

ckne_log "Enabling Cilium's egress gateway feature cluster-wide (egressGateway.enabled=true)"
helm upgrade cilium cilium/cilium --reuse-values --set egressGateway.enabled=true \
  --namespace kube-system --wait --timeout 5m
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s

EGRESS_NODE="$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')"
ckne_log "Labeling node $EGRESS_NODE as this lab's designated egress gateway ($EGRESS_NODE_LABEL=true)"
kubectl label node "$EGRESS_NODE" "${EGRESS_NODE_LABEL}=true" --overwrite

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) egress-client Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/client.yaml" | kubectl apply -f -

ckne_log "Applying broken CiliumEgressGatewayPolicy (intentional starting state — podSelector does not match the client Pods)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/egress-policy.yaml" | kubectl apply -f -

ckne_log "Waiting for egress-client Deployment to be Available"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/egress-client --timeout=120s

ckne_log "Setup complete. The CiliumEgressGatewayPolicy's podSelector intentionally does not match egress-client — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
