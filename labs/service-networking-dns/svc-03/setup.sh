#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-03"
NAMESPACE="ckne-svc-03"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying starting scaffold: shop Deployment (no Service yet — that's the task)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/deployment.yaml" | kubectl apply -f -

ckne_log "Waiting for the Deployment to become Ready"
kubectl -n "$NAMESPACE" rollout status deployment/shop --timeout=120s

ckne_log "Setup complete. Deployment shop is 2/2 Ready with no Service in front of it — create one (type: LoadBalancer)."
ckne_log "Validate with: make validate LAB=$TASK_ID"
