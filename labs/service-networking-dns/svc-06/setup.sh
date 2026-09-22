#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-06"
NAMESPACE="ckne-svc-06"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (healthy) Service"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/service.yaml" | kubectl apply -f -

ckne_log "Applying broken Deployment (intentional starting state — bad readinessProbe path)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/deployment.yaml" | kubectl apply -f -

ckne_log "Waiting for the Deployment object to be observable (it is expected to be 0/2 Ready — that is the task)"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get deployment web >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get deployment web

ckne_log "Setup complete. Deployment is intentionally not Ready yet — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
