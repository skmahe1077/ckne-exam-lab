#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-09"
NAMESPACE="ckne-svc-09"

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

ckne_log "Applying base (always-correct) web backend"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -

ckne_log "Waiting for web to become Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/web --timeout=120s

ckne_log "Setup complete. No Gateway or HTTPRoute exist yet in $NAMESPACE — web is unreachable from outside its own Service. That is the task: create both, referencing the shared GatewayClass 'cilium' by name."
ckne_log "Validate with: make validate LAB=$TASK_ID"
