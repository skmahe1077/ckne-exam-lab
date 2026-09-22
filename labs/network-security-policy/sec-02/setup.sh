#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-02"
NAMESPACE="ckne-sec-02"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base scenario objects (allowed-target, blocked-target, client)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/targets.yaml" | kubectl apply -f -
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/client.yaml" | kubectl apply -f -

ckne_log "Applying default-deny-egress NetworkPolicy (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/default-deny-egress.yaml" | kubectl apply -f -

ckne_log "Waiting for target and client Pods to be Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

ckne_log "Setup complete. client cannot reach anything (not even DNS) until egress rules are added."
ckne_log "Validate with: make validate LAB=$TASK_ID"
