#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — shared cluster-level add-on installation
#
# Installs, once, at cluster scope (never per-lab): Helm, Cilium (as both CNI
# and the cluster's Gateway API implementation) with Hubble enabled, the
# Gateway API CRDs, Istio, Prometheus, Jaeger and cert-manager.
#
# Runs entirely on the control-plane node via SSM Run Command (the node that
# already holds /etc/kubernetes/admin.conf) — no local kubeconfig is required,
# which matters because cluster-bootstrap.sh calls this script (with
# --only cilium) before download-kubeconfig.sh has ever run.
#
# Usage:
#   ./kubeadm-setup/install-addons.sh                 # install everything
#   ./kubeadm-setup/install-addons.sh --only cilium
#   ./kubeadm-setup/install-addons.sh --only gateway-api,istio
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

ONLY="all"
for ((i=1; i<=$#; i++)); do
  arg="${!i}"
  if [[ "$arg" == "--only" ]]; then
    j=$((i+1))
    ONLY="${!j}"
  fi
done

require_cmd aws jq
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

CP_ID="$(find_instances_by_role control-plane | head -n1)"
[[ -z "$CP_ID" ]] && log_fatal "No control-plane instance found. Run aws-infra-setup.sh and cluster-bootstrap.sh first."

wants() {
  [[ "$ONLY" == "all" ]] && return 0
  case ",$ONLY," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

log_step "Installing add-ons (--only=${ONLY}) on control plane ${CP_ID}"

REMOTE_SCRIPT="$(mktemp)"
{
cat <<'HEADER'
set -Eeuo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
export HELM_CACHE_HOME=/root/.cache/helm
export DEBIAN_FRONTEND=noninteractive

if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3.sh
  chmod +x /tmp/get-helm-3.sh
  /tmp/get-helm-3.sh
  rm -f /tmp/get-helm-3.sh
fi
helm version --short

kubectl create namespace ckne-lab-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "Namespace ckne-lab-system ready (used by shared/scripts/lock.sh)"
HEADER

if wants cilium; then
cat <<'CILIUM'

echo "### Gateway API CRDs (required by Cilium's gatewayAPI.enabled=true before install) ###"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null

echo "### Cilium (CNI + Gateway API implementation) + Hubble ###"
helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
helm repo update cilium >/dev/null
if helm status cilium -n kube-system >/dev/null 2>&1; then
  echo "Cilium already installed — upgrading in place (idempotent)."
fi
helm upgrade --install cilium cilium/cilium --version 1.16.5 \
  --namespace kube-system \
  --set kubeProxyReplacement=false \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set gatewayAPI.enabled=true \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList='{__POD_CIDR__}' \
  --wait --timeout 5m
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s

echo "### Shared GatewayClass 'cilium' (used by all labs — do not create per-lab GatewayClasses) ###"
cat <<'GWC' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: cilium
  labels:
    app.kubernetes.io/part-of: ckne-hands-on
spec:
  controllerName: io.cilium/gateway-controller
GWC
CILIUM
fi

if wants gateway-api; then
cat <<'GWAPI'

echo "### Gateway API CRDs ###"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null

echo "### Shared GatewayClass 'cilium' (idempotent — no-op if already created) ###"
cat <<'GWC' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: cilium
  labels:
    app.kubernetes.io/part-of: ckne-hands-on
spec:
  controllerName: io.cilium/gateway-controller
GWC
GWAPI
fi

if wants istio; then
cat <<'ISTIO'

echo "### Istio ###"
helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null 2>&1 || true
helm repo update istio >/dev/null
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install istio-base istio/base -n istio-system --version 1.24.2 --wait
helm upgrade --install istiod istio/istiod -n istio-system --version 1.24.2 --wait --timeout 5m
kubectl -n istio-system rollout status deployment/istiod --timeout=180s
ISTIO
fi

if wants prometheus; then
cat <<'PROM'

echo "### Prometheus ###"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install prometheus prometheus-community/prometheus -n monitoring --version 25.27.0 \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus-pushgateway.enabled=false \
  --wait --timeout 5m
kubectl -n monitoring rollout status deployment/prometheus-server --timeout=180s
PROM
fi

if wants jaeger; then
cat <<'JAEGER'

echo "### Jaeger ###"
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update jaegertracing >/dev/null
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install jaeger jaegertracing/jaeger -n observability --version 3.4.1 \
  --set provisionDataStore.cassandra=false \
  --set allInOne.enabled=true \
  --set storage.type=memory \
  --set collector.enabled=false \
  --set query.enabled=false \
  --set agent.enabled=false \
  --wait --timeout 5m
kubectl -n observability rollout status deployment/jaeger -l app.kubernetes.io/name=jaeger --timeout=180s || true
JAEGER
fi

if wants cert-manager; then
cat <<'CERTM'

echo "### cert-manager ###"
helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
helm repo update jetstack >/dev/null
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --version v1.16.2 \
  --set crds.enabled=true \
  --wait --timeout 5m
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=180s
CERTM
fi

echo "install-addons.sh completed (--only=${ONLY:-all})"
} > "$REMOTE_SCRIPT"

sed -i.bak "s#__POD_CIDR__#${POD_CIDR}#" "$REMOTE_SCRIPT"
rm -f "${REMOTE_SCRIPT}.bak"

remote_run "$CP_ID" "$REMOTE_SCRIPT" "install-addons(${ONLY})"
rm -f "$REMOTE_SCRIPT"

log_ok "Add-on installation complete."
