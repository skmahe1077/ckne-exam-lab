#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-02"
NAMESPACE="ckne-obs-02"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Precondition: CoreDNS must be healthy cluster-wide (this lab only reads its logs, never modifies it)"
kubectl -n kube-system rollout status deployment/coredns --timeout=120s

ckne_log "Applying broken orders Deployment + Service (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/orders.yaml" | kubectl apply -f -

ckne_log "Waiting for the orders Pods to be observable (they are expected to stay NotReady — that is the task)"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get deployment orders >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get deployment orders

ckne_log "Setup complete. orders Pods are Running but NotReady, and the Service has no Endpoints — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
