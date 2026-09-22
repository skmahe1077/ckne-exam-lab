#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-05"
NAMESPACE="ckne-obs-05"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready

ckne_log "Checking precondition: istiod is Ready in istio-system (shared, cluster-wide; this lab only reads from it)"
kubectl -n istio-system rollout status deployment/istiod --timeout=120s

ckne_log "Checking precondition: Jaeger is Ready in observability (shared, cluster-wide; this lab only reads from it)"
JAEGER_DEPLOY="$(kubectl -n observability get deployment -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$JAEGER_DEPLOY" ]]; then
  ckne_fail "No Jaeger Deployment found in the observability namespace (label app.kubernetes.io/name=jaeger). Jaeger is installed cluster-wide by kubeadm-setup/install-addons.sh — fix the cluster before running this lab."
fi
kubectl -n observability rollout status deployment/"$JAEGER_DEPLOY" --timeout=120s

ckne_log "Discovering Jaeger's query (16686) and Zipkin-compatible collector (9411) Services in observability"
JAEGER_SVC_LINES="$(kubectl -n observability get svc -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .spec.ports[*]}{.port}{","}{end}{"\n"}{end}' 2>/dev/null || true)"
JAEGER_QUERY_SVC="$(echo "$JAEGER_SVC_LINES" | awk '/16686/{print $1; exit}')"
JAEGER_COLLECTOR_SVC="$(echo "$JAEGER_SVC_LINES" | awk '/9411/{print $1; exit}')"
if [[ -z "$JAEGER_QUERY_SVC" || -z "$JAEGER_COLLECTOR_SVC" ]]; then
  ckne_fail "Could not find Jaeger Services exposing ports 16686 (query) and 9411 (Zipkin-compatible collector) in observability. Found:
$JAEGER_SVC_LINES
Fix the cluster's Jaeger install before running this lab."
fi
ckne_log "Jaeger query Service: $JAEGER_QUERY_SVC   Jaeger collector Service: $JAEGER_COLLECTOR_SVC"

ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Labeling $NAMESPACE for automatic Istio sidecar injection (must happen before any Pods are created)"
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite

ckne_log "Applying base (always-correct) backend Deployment/Service and client Pod"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/base/backend.yaml" | kubectl apply -f -

ckne_log "Waiting for backend and client to be Ready"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/backend --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/client --timeout=120s

ckne_log "Verifying both Pods actually received an istio-proxy sidecar (not just that they're Ready)"
check_sidecar() {
  local desc="$1" jsonpath_expr="$2" get_args="$3"
  local containers
  local i
  for i in $(seq 1 15); do
    # shellcheck disable=SC2086
    containers="$(kubectl -n "$NAMESPACE" get $get_args -o jsonpath="$jsonpath_expr" 2>/dev/null || true)"
    if echo "$containers" | grep -q "istio-proxy"; then
      return 0
    fi
    sleep 2
  done
  ckne_fail "$desc did not receive an istio-proxy sidecar. Check istiod's mutating webhook configuration (cluster-level) before running this lab."
}
check_sidecar "Deployment backend" '{.spec.template.spec.containers[*].name}' "deployment backend"
check_sidecar "Pod client" '{.spec.containers[*].name}' "pod client"
ckne_log "Sidecar injection confirmed on both backend and client."

ckne_log "Applying broken Telemetry (intentional starting state — access-log provider name is wrong)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
  "$LAB_DIR/manifests/broken/telemetry.yaml" | kubectl apply -f -

ckne_log "Applying broken trace-reporter-config ConfigMap (intentional starting state — wrong Jaeger collector port)"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" \
    -e "s/\${JAEGER_QUERY_SVC}/${JAEGER_QUERY_SVC}/g" -e "s/\${JAEGER_COLLECTOR_SVC}/${JAEGER_COLLECTOR_SVC}/g" \
  "$LAB_DIR/manifests/broken/trace-reporter-config.yaml" | kubectl apply -f -

ckne_log "Setup complete. Access logging is enabled with an invalid provider name, and the trace reporter points at the wrong Jaeger collector port — neither Envoy access logs nor Jaeger traces are flowing yet. That is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
