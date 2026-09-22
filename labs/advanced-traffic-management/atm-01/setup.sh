#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-01"
NAMESPACE="ckne-atm-01"

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

ckne_log "Applying broken HTTPRoute objects (intentional starting state — backendRefs/paths are swapped)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/httproute-host.yaml" | kubectl apply -f -
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/httproute-path.yaml" | kubectl apply -f -

ckne_log "Waiting for backend Deployments to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/blue --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/green --timeout=120s

ckne_log "Waiting for the Gateway to be observable (routing is intentionally still wrong — that is the task)"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get gateway atm-gw >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get gateway atm-gw
kubectl -n "$NAMESPACE" get httproute

ckne_log "Setup complete. Host- and path-based routing are intentionally swapped — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
