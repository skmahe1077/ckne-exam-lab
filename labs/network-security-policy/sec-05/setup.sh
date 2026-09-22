#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-05"
NAMESPACE="ckne-sec-05"
CLIENTS_NAMESPACE="ckne-sec-05-clients"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Creating and labeling the second (trusted client) namespace: $CLIENTS_NAMESPACE"
ckne_setup_namespace "$CLIENTS_NAMESPACE" "$TASK_ID"
kubectl label namespace "$CLIENTS_NAMESPACE" team=payments --overwrite

ckne_log "Applying starting scenario in $NAMESPACE (backend, rogue-frontend — no NetworkPolicy yet)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/backend.yaml" | kubectl apply -f -

ckne_log "Applying frontend-a and worker-a into $CLIENTS_NAMESPACE"
sed -e "s/\${CLIENTS_NAMESPACE}/${CLIENTS_NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/clients.yaml" | kubectl apply -f -

ckne_log "Waiting for Pods to be Ready in both namespaces"
ckne_wait_pods_ready "$NAMESPACE" 120s
ckne_wait_pods_ready "$CLIENTS_NAMESPACE" 120s

ckne_log "Setup complete. backend currently accepts ingress from ANY Pod (namespace or role alone is not"
ckne_log "yet enforced as a combined AND condition) — that is the task to fix."
ckne_log "Validate with: make validate LAB=$TASK_ID"
