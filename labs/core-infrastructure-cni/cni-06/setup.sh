#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-06"
NAMESPACE="ckne-cni-06"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

apply() {
  sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" "$1" | kubectl apply -f -
}

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base Services (data-svc, mgmt-svc) and client Pods"
apply "$LAB_DIR/manifests/base/services.yaml"
apply "$LAB_DIR/manifests/base/clients.yaml"

ckne_log "Applying multi-iface-app Deployment (two containers, two ports; no NetworkPolicy yet)"
apply "$LAB_DIR/manifests/broken/deployment.yaml"

ckne_log "Waiting for multi-iface-app to become Ready (both containers)"
kubectl -n "$NAMESPACE" rollout status deployment/multi-iface-app --timeout=120s

ckne_log "Waiting for client Pods to become Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

ckne_log "Setup complete. No NetworkPolicy exists yet, so both client and"
ckne_log "admin-client can currently reach BOTH data-svc and mgmt-svc — that is the task to fix."
ckne_log "Validate with: make validate LAB=$TASK_ID"
