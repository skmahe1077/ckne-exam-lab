#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-04"
NAMESPACE="ckne-obs-04"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

ckne_log "Checking precondition: shared Prometheus server is Ready in monitoring (read-only; this lab never modifies it)"
kubectl -n monitoring rollout status deployment/prometheus-server --timeout=120s

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) netmetrics app"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/netmetrics-app.yaml" | kubectl apply -f -

ckne_log "Applying broken netmetrics Service (intentional starting state — wrong prometheus.io/port annotation)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/netmetrics-service.yaml" | kubectl apply -f -

ckne_log "Waiting for netmetrics to become Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/netmetrics --timeout=120s

ckne_log "Setup complete. netmetrics serves /metrics on 8080, but its Service advertises the wrong scrape port — Prometheus cannot reach it yet. That is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
