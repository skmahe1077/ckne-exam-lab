#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-06"
NAMESPACE="ckne-obs-06"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

ckne_log "Checking precondition: Cilium (Hubble) is Ready cluster-wide"
kubectl -n kube-system rollout status daemonset/cilium --timeout=120s

ckne_log "Checking precondition: shared Prometheus server is Ready in monitoring"
kubectl -n monitoring rollout status deployment/prometheus-server --timeout=120s

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) backend app, Service, and client Pod"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -

ckne_log "Waiting for backend and client to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/backend --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/client --timeout=120s

ckne_log "Applying broken client-config (intentional starting state — timeout far tighter than backend's real latency)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/client-config.yaml" | kubectl apply -f -

ckne_log "Setup complete. backend genuinely takes ~3s per request; client-config's timeout is only 1s — every request currently fails before backend can respond. That is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
