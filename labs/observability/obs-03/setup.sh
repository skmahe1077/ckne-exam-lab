#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-03"
NAMESPACE="ckne-obs-03"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

ckne_log "Checking precondition: Hubble relay is running in kube-system (shared, cluster-wide; this lab only reads from it)"
if ! kubectl -n kube-system get deployment hubble-relay >/dev/null 2>&1; then
  ckne_fail "Deployment hubble-relay not found in kube-system. Hubble is installed cluster-wide by kubeadm-setup/install-addons.sh — fix the cluster before running this lab."
fi

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base (always-correct) web Deployment + Service"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/web.yaml" | kubectl apply -f -

ckne_log "Applying base (always-correct) client-a / client-b Pods"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/clients.yaml" | kubectl apply -f -

ckne_log "Applying broken NetworkPolicy (intentional starting state — allow/deny selector is inverted)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/networkpolicy.yaml" | kubectl apply -f -

ckne_log "Waiting for web and both clients to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/web --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/client-a --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/client-b --timeout=120s

ckne_log "Setup complete. client-a (role=allowed) is currently BLOCKED and client-b (role=blocked) is currently ALLOWED — the policy selector is inverted. That is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
