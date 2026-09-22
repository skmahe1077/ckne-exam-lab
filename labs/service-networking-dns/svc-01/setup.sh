#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-01"
NAMESPACE="ckne-svc-01"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (healthy) Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/deployment.yaml" | kubectl apply -f -

ckne_log "Applying broken Service (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/service.yaml" | kubectl apply -f -

ckne_log "Waiting for the Deployment to become Ready (this part is expected to succeed)"
kubectl -n "$NAMESPACE" rollout status deployment/api --timeout=120s

ckne_log "Setup complete. Deployment api is 2/2 Ready, but its Service has no Endpoints — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
