#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-07"
NAMESPACE="ckne-sec-07"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base client Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/client.yaml" | kubectl apply -f -

ckne_log "Applying broken (incomplete) default-deny-all-egress NetworkPolicy"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/networkpolicy.yaml" | kubectl apply -f -

ckne_log "Waiting for client Deployment to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/client --timeout=120s

ckne_log "Setup complete. Egress is fully denied right now — client cannot even resolve DNS."
ckne_log "Validate with: make validate LAB=$TASK_ID"
