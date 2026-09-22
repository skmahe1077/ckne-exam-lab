#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-02"
NAMESPACE="ckne-svc-02"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (healthy) Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/deployment.yaml" | kubectl apply -f -

ckne_log "Applying broken NodePort Service (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/service.yaml" | kubectl apply -f -

ckne_log "Waiting for the Deployment to become Ready (this part is expected to succeed)"
kubectl -n "$NAMESPACE" rollout status deployment/web --timeout=120s

ckne_log "Waiting for a nodePort to be allocated"
for _ in $(seq 1 30); do
  NP="$(kubectl -n "$NAMESPACE" get svc web -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"
  if [[ -n "$NP" ]]; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get svc web

ckne_log "Setup complete. Service web has a nodePort and healthy Endpoints, but targetPort is wrong — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
