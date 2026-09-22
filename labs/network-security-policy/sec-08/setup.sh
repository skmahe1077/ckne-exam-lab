#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-08"
NAMESPACE="ckne-sec-08"
LOCK_RESOURCE="cilium-config"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

apply() {
  sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" "$1" | kubectl apply -f -
}

ckne_require_nodes_ready

# Precondition: CiliumNetworkPolicy is a CRD Cilium installs — make sure it exists.
if ! kubectl get crd ciliumnetworkpolicies.cilium.io >/dev/null 2>&1; then
  ckne_fail "CRD ciliumnetworkpolicies.cilium.io not found — this cluster's Cilium installation is missing or broken (cluster-level issue, not part of this lab)."
fi

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Applying base client Pods (caller, outsider)"
apply "$LAB_DIR/manifests/base/clients.yaml"

ckne_log "Applying starting backend (no CiliumNetworkPolicy yet — accepts everything)"
apply "$LAB_DIR/manifests/broken/backend.yaml"

ckne_log "Waiting for backend to become Ready"
kubectl -n "$NAMESPACE" rollout status deployment/backend --timeout=120s

ckne_log "Waiting for client Pods to become Ready"
ckne_wait_pods_ready "$NAMESPACE" 120s

ckne_log "Part B: acquiring shared lock '$LOCK_RESOURCE' before changing cluster-wide Cilium Helm values"
if ! "$REPO_ROOT/shared/scripts/lock.sh" acquire "$LOCK_RESOURCE" "$TASK_ID"; then
  ckne_fail "Could not acquire lock '$LOCK_RESOURCE' — another lab (e.g. ATM-05) is currently using it. Wait for it to finish, or ask a human to run: make release-stale-lock LAB=<holder>"
fi

ckne_log "Part B: this is expected to still be Ready with WireGuard OFF right now — enabling it is the task"
kubectl -n kube-system rollout status daemonset/cilium --timeout=120s

ckne_log "Setup complete."
ckne_log "Part A: backend currently accepts ANY path/method from ANY Pod — add a CiliumNetworkPolicy to fix that."
ckne_log "Part B: WireGuard transparent encryption is currently OFF — enable it via Helm (lock '$LOCK_RESOURCE' is held by $TASK_ID)."
ckne_log "Validate with: make validate LAB=$TASK_ID"
