#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-04"
NAMESPACE="ckne-atm-04"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

apply() {
  sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" "$1" | kubectl apply -f -
}

ckne_log "Applying base backend, cert-manager Issuer/Certificate, and HTTPRoute"
apply "$LAB_DIR/manifests/base/backend.yaml"
apply "$LAB_DIR/manifests/base/cert.yaml"
apply "$LAB_DIR/manifests/base/httproute.yaml"

ckne_log "Applying broken Gateway (certificateRefs points at the wrong name)"
apply "$LAB_DIR/manifests/broken/gateway.yaml"

ckne_log "Waiting for the backend Deployment to become Ready"
kubectl -n "$NAMESPACE" rollout status deployment/web --timeout=120s

ckne_log "Waiting for the Certificate to be issued (this part is expected to succeed)"
kubectl -n "$NAMESPACE" wait --for=condition=Ready certificate/ckne-atm-04-cert --timeout=120s

ckne_log "Setup complete. The Certificate is Ready but the Gateway's certificateRefs points at the wrong Secret name — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
