#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-02"
NAMESPACE="ckne-cni-02"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (healthy) server Deployment + Service"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/server.yaml" | kubectl apply -f -

ckne_log "Applying broken client Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/client.yaml" | kubectl apply -f -

ckne_log "Applying broken NetworkPolicy (ipBlock CIDR does not match the real Pod CIDR)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/networkpolicy.yaml" | kubectl apply -f -

ckne_log "Waiting for server and client Pods to become Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

kubectl -n "$NAMESPACE" get pods -o wide
kubectl -n "$NAMESPACE" get networkpolicy

ckne_log "Setup complete. Both Pods are Ready, but traffic from client to server is blocked."
ckne_log "Validate with: make validate LAB=$TASK_ID"
