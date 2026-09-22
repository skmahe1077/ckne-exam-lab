#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-06"
NAMESPACE="ckne-atm-06"
CLUSTER_NAME="ckne-hands-on"
CLUSTER_ID="1"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

ckne_log "Acquiring shared-resource lock 'clustermesh' (this lab deploys the cluster-wide clustermesh-apiserver into kube-system)"
"$REPO_ROOT/shared/scripts/lock.sh" acquire clustermesh "$TASK_ID"

ckne_log "SCOPE NOTE: only one real cluster exists in this environment. This lab"
ckne_log "enables and inspects the Cilium ClusterMesh control plane (clustermesh-apiserver"
ckne_log "and its generated mTLS certificates) as a configuration/readiness exercise."
ckne_log "It does NOT connect a second cluster and cannot test real cross-cluster"
ckne_log "traffic. See concept.md and task.md for the full scope limitation."

ckne_log "Enabling Cilium Cluster Mesh's control-plane components (clustermesh-apiserver) in kube-system"
helm upgrade cilium cilium/cilium --reuse-values \
  --set cluster.name="$CLUSTER_NAME" \
  --set cluster.id="$CLUSTER_ID" \
  --set clustermesh.useAPIServer=true \
  --set clustermesh.apiserver.tls.auto.enabled=true \
  --set clustermesh.apiserver.tls.auto.method=helm \
  --set clustermesh.apiserver.service.type=ClusterIP \
  --namespace kube-system --wait --timeout 5m
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
kubectl -n kube-system rollout status deployment/clustermesh-apiserver --timeout=180s

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) catalog Deployment"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/catalog-deployment.yaml" | kubectl apply -f -

ckne_log "Applying broken catalog Service (intentional starting state — missing the ClusterMesh global-service annotation)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/catalog-service.yaml" | kubectl apply -f -

ckne_log "Waiting for catalog Deployment to be Available"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/catalog --timeout=120s

ckne_log "Setup complete. clustermesh-apiserver is up; the catalog Service is not yet marked as a ClusterMesh global service — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
