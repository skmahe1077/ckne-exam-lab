#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-03"
NAMESPACE="ckne-sec-03"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying starting scenario (backend Deployment/Service, client Pods — no NetworkPolicy yet)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/backend.yaml" | kubectl apply -f -
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/clients.yaml" | kubectl apply -f -

ckne_log "Waiting for backend and client Pods to be Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

ckne_log "Setup complete. backend currently accepts ingress from ANY Pod — that is the task to fix."
ckne_log "Validate with: make validate LAB=$TASK_ID"
