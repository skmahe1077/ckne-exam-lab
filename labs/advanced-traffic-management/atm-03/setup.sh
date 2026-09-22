#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-03"
NAMESPACE="ckne-atm-03"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

ckne_log "Checking precondition: shared GatewayClass 'cilium' is Accepted"
GWC_ACCEPTED="$(kubectl get gatewayclass cilium -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")"
if [[ "$GWC_ACCEPTED" != "True" ]]; then
  ckne_fail "GatewayClass 'cilium' is not Accepted (status: '${GWC_ACCEPTED:-<missing>}'). This is a shared cluster-level resource installed by kubeadm-setup/install-addons.sh — fix the cluster before running this lab."
fi

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) backends and Gateway"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backends.yaml" | kubectl apply -f -
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/gateway.yaml" | kubectl apply -f -

ckne_log "Applying starting HTTPRoute (intentionally an even 50/50 weight split)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/httproute.yaml" | kubectl apply -f -

ckne_log "Waiting for backend Deployments to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/stable --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/canary --timeout=120s

ckne_log "Waiting for the Gateway to be observable (the split is intentionally 50/50, not 80/20, yet — that is the task)"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get gateway atm-gw >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get gateway atm-gw
kubectl -n "$NAMESPACE" get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs}'
echo

ckne_log "Setup complete. Change the backendRefs weights to an 80/20 stable/canary split."
ckne_log "Validate with: make validate LAB=$TASK_ID"
