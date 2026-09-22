#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-09"
NAMESPACE="ckne-sec-09"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

apply() {
  sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" "$1" | kubectl apply -f -
}

ckne_require_nodes_ready

# Precondition: cert-manager itself must be installed cluster-wide.
if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  ckne_fail "CRD certificates.cert-manager.io not found — cert-manager is not installed on this cluster (cluster-level issue, not part of this lab)."
fi

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base backend Service and backend-identity ServiceAccount"
apply "$LAB_DIR/manifests/base/backend.yaml"

ckne_log "Applying starting backend-workload Deployment (running under the default ServiceAccount)"
apply "$LAB_DIR/manifests/broken/backend-workload.yaml"

ckne_log "Waiting for backend-workload to become Ready"
kubectl -n "$NAMESPACE" rollout status deployment/backend-workload --timeout=120s

ckne_log "Setup complete. No Issuer/Certificate exists yet (Part A), and backend-workload"
ckne_log "is still running under the default ServiceAccount, not backend-identity (Part B)."
ckne_log "Validate with: make validate LAB=$TASK_ID"
