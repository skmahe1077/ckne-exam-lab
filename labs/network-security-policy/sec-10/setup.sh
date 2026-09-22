#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-10"
NAMESPACE="ckne-sec-10"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

apply() {
  sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" "$1" | kubectl apply -f -
}

# wait_for_sidecar <pod-name> — bounded retry until the Pod reports an
# istio-proxy container in its spec (i.e. the mutating webhook actually
# injected it), or fails after ~60s.
wait_for_sidecar() {
  local pod="$1"
  local containers
  for _ in $(seq 1 30); do
    containers="$(kubectl -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"
    case " $containers " in
      *" istio-proxy "*) return 0 ;;
    esac
    sleep 2
  done
  return 1
}

ckne_require_nodes_ready

# Precondition: Istio's control plane (istiod) must be healthy, and the
# sidecar injection webhook must exist — otherwise labeling the namespace
# would silently do nothing.
if ! kubectl -n istio-system get deployment istiod >/dev/null 2>&1; then
  ckne_fail "Deployment istiod not found in istio-system — Istio is not installed on this cluster (cluster-level issue, not part of this lab)."
fi
kubectl -n istio-system rollout status deployment/istiod --timeout=120s

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Labeling $NAMESPACE for Istio sidecar injection"
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite

ckne_log "Applying caller ServiceAccounts and Pods (trusted-caller, untrusted-caller, no-mesh-caller)"
apply "$LAB_DIR/manifests/base/callers.yaml"

ckne_log "Applying starting backend (no PeerAuthentication/AuthorizationPolicy yet)"
apply "$LAB_DIR/manifests/broken/backend.yaml"

ckne_log "Waiting for backend to become Ready"
kubectl -n "$NAMESPACE" rollout status deployment/backend --timeout=120s

ckne_log "Waiting for all Pods to become Ready"
ckne_wait_pods_ready "$NAMESPACE" 180s

ckne_log "Confirming sidecars actually injected (backend, trusted-caller, untrusted-caller)"
BACKEND_POD="$(kubectl -n "$NAMESPACE" get pods -l app=backend -o jsonpath='{.items[0].metadata.name}')"
for pod in "$BACKEND_POD" trusted-caller untrusted-caller; do
  if ! wait_for_sidecar "$pod"; then
    ckne_fail "Pod $pod never got an istio-proxy sidecar — check the istio-injection label on $NAMESPACE and the istiod webhook."
  fi
  ckne_log "  $pod: sidecar present"
done

ckne_log "Confirming no-mesh-caller intentionally has NO sidecar (opted out via annotation)"
NO_MESH_CONTAINERS="$(kubectl -n "$NAMESPACE" get pod no-mesh-caller -o jsonpath='{.spec.containers[*].name}')"
case " $NO_MESH_CONTAINERS " in
  *" istio-proxy "*) ckne_fail "no-mesh-caller unexpectedly got a sidecar — its sidecar.istio.io/inject: \"false\" annotation should have prevented injection." ;;
  *) ckne_log "  no-mesh-caller: no sidecar, as intended" ;;
esac

ckne_log "Setup complete. backend currently accepts plaintext from anyone — adding STRICT"
ckne_log "PeerAuthentication and an identity-scoped AuthorizationPolicy is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
