#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-04"
NAMESPACE="ckne-svc-04"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying broken ExternalName Service (intentional starting state)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/service.yaml" | kubectl apply -f -

ckne_log "Waiting for the Service object to be observable"
for _ in $(seq 1 30); do
  if kubectl -n "$NAMESPACE" get svc docs >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "$NAMESPACE" get svc docs

ckne_log "Setup complete. Service docs is ExternalName but points at a non-existent domain — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
