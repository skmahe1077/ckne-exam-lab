#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-01"
NAMESPACE="ckne-obs-01"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (healthy) backend Deployment + Service"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -

ckne_log "Waiting for backend to become Ready"
kubectl -n "$NAMESPACE" rollout status deployment/backend --timeout=120s

ckne_log "Applying broken netprobe Deployment (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/netprobe.yaml" | kubectl apply -f -

ckne_log "Waiting for netprobe to be observable (it is expected to crash-loop — that is the task)"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get deployment netprobe >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get deployment netprobe

ckne_log "Setup complete. netprobe Pods are expected to be crash-looping — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
