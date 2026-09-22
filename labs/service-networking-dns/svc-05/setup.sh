#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-05"
NAMESPACE="ckne-svc-05"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying broken (non-headless) Service first, so the StatefulSet's serviceName reference resolves as it starts"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/service.yaml" | kubectl apply -f -

ckne_log "Applying base (healthy) StatefulSet"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/statefulset.yaml" | kubectl apply -f -

ckne_log "Waiting for the StatefulSet to become Ready (this part is expected to succeed)"
kubectl -n "$NAMESPACE" rollout status statefulset/web --timeout=180s

ckne_log "Setup complete. StatefulSet web is 3/3 Ready, but its governing Service is not headless — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
