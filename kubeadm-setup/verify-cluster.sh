#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — cluster verification
#
# Read-only (aside from a self-cleaning connectivity test namespace). Runs on
# the control plane via SSM so it works with or without a local kubeconfig.
# Exits non-zero if any REQUIRED check fails; add-ons installed via a partial
# `install-addons.sh --only ...` are reported as SKIPPED, not FAILED.
# ==============================================================================
set -Eeuo pipefail
export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"
# shellcheck source=lib/aws.sh
source "$SCRIPT_DIR/lib/aws.sh"
# shellcheck source=lib/kubernetes.sh
source "$SCRIPT_DIR/lib/kubernetes.sh"

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

CP_ID="$(find_instances_by_role control-plane | head -n1)"
[[ -z "$CP_ID" ]] && log_fatal "No control-plane instance found."

log_step "Verifying cluster on control plane ${CP_ID}"

REMOTE_SCRIPT="$(mktemp)"
cat <<'EOF' > "$REMOTE_SCRIPT"
set -Eeuo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/tmp/ckne-check.log 2>&1; then
    printf 'PASS  %s\n' "$desc"
  else
    printf 'FAIL  %s\n' "$desc"
    sed 's/^/      /' /tmp/ckne-check.log | tail -n5
    FAIL=1
  fi
}

skip_if_absent() {
  local desc="$1" probe_kind="$2" probe_name="$3" probe_ns="$4"; shift 4
  if ! kubectl -n "$probe_ns" get "$probe_kind" "$probe_name" >/dev/null 2>&1; then
    printf 'SKIP  %s (not installed)\n' "$desc"
    return 1
  fi
  return 0
}

echo "== Required: kubeadm cluster =="
check "All nodes Ready"            kubectl wait --for=condition=Ready node --all --timeout=60s
check "CoreDNS rollout"            kubectl -n kube-system rollout status deployment/coredns --timeout=60s
check "kube-proxy daemonset ready" kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=60s

echo ""
echo "== Add-ons (SKIP = not installed via install-addons.sh --only ...) =="
if skip_if_absent "Cilium daemonset ready" daemonset cilium kube-system; then
  check "Cilium daemonset ready" kubectl -n kube-system rollout status daemonset/cilium --timeout=60s
fi
if skip_if_absent "Hubble relay ready" deployment hubble-relay kube-system; then
  check "Hubble relay ready" kubectl -n kube-system rollout status deployment/hubble-relay --timeout=60s
fi
if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  printf 'PASS  Gateway API CRDs installed\n'
else
  printf 'SKIP  Gateway API CRDs (not installed)\n'
fi
if skip_if_absent "Istiod ready" deployment istiod istio-system; then
  check "Istiod ready" kubectl -n istio-system rollout status deployment/istiod --timeout=60s
fi
if skip_if_absent "Prometheus server ready" deployment prometheus-server monitoring; then
  check "Prometheus server ready" kubectl -n monitoring rollout status deployment/prometheus-server --timeout=60s
fi
if kubectl -n observability get pods -l app.kubernetes.io/name=jaeger >/dev/null 2>&1 && [ -n "$(kubectl -n observability get pods -l app.kubernetes.io/name=jaeger -o name)" ]; then
  printf 'PASS  Jaeger pod present\n'
else
  printf 'SKIP  Jaeger (not installed)\n'
fi
if skip_if_absent "cert-manager ready" deployment cert-manager cert-manager; then
  check "cert-manager ready" kubectl -n cert-manager rollout status deployment/cert-manager --timeout=60s
fi

echo ""
echo "== Connectivity self-test =="
NS=ckne-verify-selftest
kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null
kubectl -n "$NS" run verify-a --image=busybox:1.36 --restart=Never -- sleep 300 >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/verify-a --timeout=60s >/dev/null
check "Pod DNS resolves kubernetes.default" kubectl -n "$NS" exec verify-a -- nslookup kubernetes.default.svc.cluster.local
check "Pod reaches Kubernetes API (TCP 443)" kubectl -n "$NS" exec verify-a -- sh -c 'nc -z -w3 kubernetes.default.svc.cluster.local 443'
kubectl delete namespace "$NS" --wait=true --timeout=120s >/dev/null 2>&1 || true

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: PASS — required cluster checks succeeded."
else
  echo "RESULT: FAIL — see failures above."
fi
exit "$FAIL"
EOF

remote_run "$CP_ID" "$REMOTE_SCRIPT" "verify-cluster"
RC=$?
rm -f "$REMOTE_SCRIPT"

if [[ $RC -eq 0 ]]; then
  log_ok "Cluster verification passed."
else
  log_error "Cluster verification reported failures."
fi
exit $RC
