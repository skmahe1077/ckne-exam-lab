#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-06"
NAMESPACE="ckne-sec-06"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Discovering worker nodes (control-plane nodes excluded)"
WORKERS=( $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}') )
if [[ "${#WORKERS[@]}" -lt 2 ]]; then
  ckne_fail "Need at least 2 worker nodes to build a deterministic ipBlock scenario, found ${#WORKERS[@]}: ${WORKERS[*]:-none}"
fi
NODE_A="${WORKERS[0]}"
NODE_B="${WORKERS[1]}"
ckne_log "NODE_A=$NODE_A  NODE_B=$NODE_B"

# Pod CIDR discovery: try the standard node.spec.podCIDR first (set when
# kube-controller-manager runs with --allocate-node-cidrs), fall back to the
# CiliumNode CRD (populated when Cilium's own cluster-pool IPAM manages
# per-node allocation instead).
get_pod_cidr() {
  local node="$1" cidr
  cidr="$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}' 2>/dev/null || true)"
  if [[ -z "$cidr" ]]; then
    cidr="$(kubectl get ciliumnode "$node" -o jsonpath='{.spec.ipam.podCIDRs[0]}' 2>/dev/null || true)"
  fi
  echo "$cidr"
}

CIDR_A="$(get_pod_cidr "$NODE_A")"
CIDR_B="$(get_pod_cidr "$NODE_B")"
if [[ -z "$CIDR_A" || -z "$CIDR_B" ]]; then
  ckne_fail "Could not determine Pod CIDR for $NODE_A ($CIDR_A) / $NODE_B ($CIDR_B) via node.spec.podCIDR or CiliumNode — cannot build lab"
fi
ckne_log "CIDR_A=$CIDR_A  CIDR_B=$CIDR_B"

ckne_log "Recording discovered node/CIDR facts in a ConfigMap for the student to read"
kubectl -n "$NAMESPACE" create configmap node-cidrs \
  --from-literal=node-a="$NODE_A" \
  --from-literal=node-a-cidr="$CIDR_A" \
  --from-literal=node-b="$NODE_B" \
  --from-literal=node-b-cidr="$CIDR_B"
kubectl -n "$NAMESPACE" label configmap node-cidrs \
  app.kubernetes.io/part-of=ckne-hands-on "ckne.openai.com/lab-id=${TASK_ID}" --overwrite

ckne_log "Applying base (healthy) backend Deployment + Service"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -

ckne_log "Applying base client Pods (pinned one per worker node)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  -e "s/\${NODE_A}/${NODE_A}/g" -e "s/\${NODE_B}/${NODE_B}/g" \
  "$LAB_DIR/manifests/base/clients.yaml" | kubectl apply -f -

ckne_log "Applying broken (incomplete) NetworkPolicy — missing the except sub-range"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/networkpolicy.yaml" | kubectl apply -f -

ckne_log "Waiting for backend Deployment and both client Pods to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/backend --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/client-a pod/client-b --timeout=120s

ckne_log "Setup complete. NetworkPolicy 'restrict-backend-ingress' currently allows ingress from"
ckne_log "the whole Pod CIDR — client-b (on $NODE_B) can currently reach backend and should not be able to."
ckne_log "Validate with: make validate LAB=$TASK_ID"
