#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-07"
NAMESPACE="ckne-svc-07"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying starting scaffold: web Deployment (no Service yet — that is the task)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/deployment.yaml" | kubectl apply -f -

ckne_log "Waiting for web Deployment to become Ready (this part is not broken — only the missing Service is the task)"
kubectl -n "$NAMESPACE" rollout status deployment/web --timeout=120s

ckne_log "Setup complete. No Service exists yet for 'web' — creating and verifying it is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
