#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-01"
NAMESPACE="ckne-sec-01"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base scenario objects (backend Deployment/Service, client Pods)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/clients.yaml" | kubectl apply -f -

ckne_log "Applying default-deny-ingress NetworkPolicy (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/default-deny-ingress.yaml" | kubectl apply -f -

ckne_log "Waiting for backend and client Pods to be Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

ckne_log "Setup complete. All ingress to 'backend' is currently denied, including from client-frontend."
ckne_log "Validate with: make validate LAB=$TASK_ID"
