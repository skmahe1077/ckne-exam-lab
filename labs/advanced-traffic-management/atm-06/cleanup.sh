#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-06"
NAMESPACE="ckne-atm-06"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

ckne_log "Disabling Cluster Mesh and removing clustermesh-apiserver from kube-system — restoring the well-known original (single-cluster, no ClusterMesh) state"
if helm status cilium -n kube-system >/dev/null 2>&1; then
  helm upgrade cilium cilium/cilium --reuse-values \
    --set clustermesh.useAPIServer=false \
    --set cluster.name=default \
    --set cluster.id=0 \
    --namespace kube-system --wait --timeout 5m
  kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
else
  ckne_warn "Cilium Helm release not found in kube-system — skipping ClusterMesh revert (nothing to revert)"
fi

ckne_log "Deleting any leftover clustermesh-apiserver TLS secrets"
for secret in clustermesh-apiserver-server-cert clustermesh-apiserver-admin-cert clustermesh-apiserver-remote-cert clustermesh-apiserver-local-cert; do
  kubectl -n kube-system delete secret "$secret" --ignore-not-found
done

ckne_log "Releasing shared-resource lock 'clustermesh'"
"$REPO_ROOT/shared/scripts/lock.sh" release clustermesh "$TASK_ID"

ckne_log "Deleting namespace $NAMESPACE"
ckne_delete_namespace "$NAMESPACE"

if ckne_verify_namespace_gone "$NAMESPACE"; then
  ckne_log "Namespace $NAMESPACE gone."
else
  ckne_fail "Namespace $NAMESPACE still exists after cleanup"
fi

if kubectl -n kube-system get deployment clustermesh-apiserver >/dev/null 2>&1; then
  ckne_fail "clustermesh-apiserver Deployment still exists in kube-system after cleanup"
fi

ckne_log "Cleanup verified: clustermesh-apiserver removed, cluster.name/cluster.id reverted, lock released, namespace gone."
exit 0
