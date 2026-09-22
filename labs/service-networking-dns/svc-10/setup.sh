#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-10"
NAMESPACE="ckne-svc-10"
BACKEND_NAMESPACE="ckne-svc-10-backend"

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

ckne_log "Creating and labeling the second (backend) namespace: $BACKEND_NAMESPACE"
ckne_setup_namespace "$BACKEND_NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) backend Deployment/Service in $BACKEND_NAMESPACE"
sed -e "s/\${BACKEND_NAMESPACE}/${BACKEND_NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -

ckne_log "Applying base (always-correct) Gateway in $NAMESPACE"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/gateway.yaml" | kubectl apply -f -

ckne_log "Applying base (always-correct) HTTPRoute with a cross-namespace backendRef in $NAMESPACE"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${BACKEND_NAMESPACE}/${BACKEND_NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/httproute.yaml" | kubectl apply -f -

ckne_log "Waiting for backend to become Ready"
kubectl -n "$BACKEND_NAMESPACE" wait --for=condition=Available deployment/backend --timeout=120s

ckne_log "Waiting for the Gateway and HTTPRoute to be observable (the cross-namespace backendRef is intentionally still rejected — that is the task)"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get gateway svc10-gw >/dev/null 2>&1 && kubectl -n "$NAMESPACE" get httproute web-route >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get gateway svc10-gw
kubectl -n "$NAMESPACE" get httproute web-route

ckne_log "Setup complete. The HTTPRoute's cross-namespace backendRef into $BACKEND_NAMESPACE has no ReferenceGrant yet — it is rejected. That is the task: create the ReferenceGrant in $BACKEND_NAMESPACE."
ckne_log "Validate with: make validate LAB=$TASK_ID"
