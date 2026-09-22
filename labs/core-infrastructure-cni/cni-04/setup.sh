#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-04"
NAMESPACE="ckne-cni-04"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (healthy) client Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/client.yaml" | kubectl apply -f -

ckne_log "Applying broken server Pod + Service (Service targetPort mismatch)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/server.yaml" | kubectl apply -f -

ckne_log "Waiting for client and server Pods to become Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

kubectl -n "$NAMESPACE" get pods -o wide
kubectl -n "$NAMESPACE" get svc server

ckne_log "Setup complete. Both Pods are Ready, but the Service does not actually route traffic to nginx."
ckne_log "Validate with: make validate LAB=$TASK_ID"
