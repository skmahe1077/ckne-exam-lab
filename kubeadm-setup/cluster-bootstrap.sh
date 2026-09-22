#!/usr/bin/env bash
# ==============================================================================
# CKNE Hands-On Practice — Kubernetes cluster bootstrap
#
# Idempotent end-to-end bootstrap: discovers nodes, runs common.sh on all of
# them, initializes the control plane, joins the workers, installs Cilium +
# Hubble, and verifies the cluster is actually usable (Ready nodes, CoreDNS,
# cross-node pod connectivity, Service DNS).
#
# Transport: SSM Run Command by default. Falls back to SSH ONLY if
# ENABLE_SSH=true in cluster.env AND SSM registration does not succeed within
# the wait window below.
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

require_cmd aws jq envsubst
load_cluster_env
refresh_project_tag_filters
verify_aws_identity

# ── 1. Discover nodes by project tags ────────────────────────────────────────
log_step "1/15 Discovering cluster nodes"
CP_ID="$(find_instances_by_role control-plane | { head -n1; cat >/dev/null; })"
WORKER_IDS=( $(find_instances_by_role worker) )

if [[ -z "$CP_ID" ]]; then
  log_fatal "No control-plane instance found. Run ./kubeadm-setup/aws-infra-setup.sh first."
fi
if [[ ${#WORKER_IDS[@]} -eq 0 ]]; then
  log_fatal "No worker instances found. Run ./kubeadm-setup/aws-infra-setup.sh first."
fi
log_info "Control plane: $CP_ID"
log_info "Workers: ${WORKER_IDS[*]}"
ALL_IDS=("$CP_ID" "${WORKER_IDS[@]}")

# ── 2. Wait for SSM connectivity (fall back to SSH only if explicitly enabled) ──
log_step "2/15 Waiting for SSM connectivity"
CKNE_TRANSPORT="ssm"
export CKNE_TRANSPORT
SSM_OK=true
for id in "${ALL_IDS[@]}"; do
  if ! wait_for_ssm_registration "$id" 180; then
    SSM_OK=false
    break
  fi
done
if [[ "$SSM_OK" != "true" ]]; then
  if [[ "$ENABLE_SSH" == "true" ]]; then
    log_warn "SSM registration incomplete — falling back to SSH (ENABLE_SSH=true)."
    CKNE_TRANSPORT="ssh"
    export CKNE_TRANSPORT
  else
    log_fatal "SSM registration incomplete and ENABLE_SSH=false — cannot continue. Check the instance profile / VPC egress, or set ENABLE_SSH=true with ALLOWED_ADMIN_CIDR for a fallback."
  fi
fi

# ── 3. Common node setup on all nodes ────────────────────────────────────────
log_step "3/15 Running common.sh on all nodes"
for id in "${ALL_IDS[@]}"; do
  header="$(mktemp)"
  printf 'export KUBERNETES_VERSION=%q\n' "$KUBERNETES_VERSION" > "$header"
  cat "$SCRIPT_DIR/common.sh" >> "$header"
  remote_run "$id" "$header" "common-setup"
  rm -f "$header"
  log_ok "common.sh completed on $id"
done

# ── 4. Generate kubeadm configuration dynamically ────────────────────────────
log_step "4/15 Generating kubeadm configuration"
CP_PRIVATE_IP="$(instance_private_ip "$CP_ID")"
[[ -z "$CP_PRIVATE_IP" || "$CP_PRIVATE_IP" == "None" ]] && log_fatal "Could not determine control-plane private IP"

VERSION_OUT="$(remote_run "$CP_ID" <(printf 'kubeadm version -o short\n') "kubeadm-version")"
KUBERNETES_VERSION_FULL="$(printf '%s' "$VERSION_OUT" | tr -d '\r' | tail -n1 | sed 's/^v//')"
[[ -z "$KUBERNETES_VERSION_FULL" ]] && log_fatal "Could not determine installed kubeadm version on $CP_ID"
log_info "Installed Kubernetes version: v${KUBERNETES_VERSION_FULL}"

export ADVERTISE_ADDRESS="$CP_PRIVATE_IP"
export CONTROL_PLANE_ENDPOINT="${CP_PRIVATE_IP}:6443"
export NODE_NAME="$CONTROL_PLANE_NAME"
export KUBERNETES_VERSION_FULL
export POD_CIDR
export SERVICE_CIDR

RENDERED_CONFIG="$(mktemp)"
render_kubeadm_config "$RENDERED_CONFIG"
ssm_write_file "$CP_ID" "/tmp/ckne/kubeadm.config" "$RENDERED_CONFIG" "write-kubeadm-config"
rm -f "$RENDERED_CONFIG"

# ── 5+6. Initialize control plane, configure kubeconfig ─────────────────────
log_step "5/15 Initializing control plane"
ssm_run_with_env "$CP_ID" "$SCRIPT_DIR/control-plane-setup.sh" "control-plane-init" \
  NODE_NAME "$CONTROL_PLANE_NAME"
log_ok "Control plane initialized: $CONTROL_PLANE_NAME"

# ── 7. Generate short-lived join command ─────────────────────────────────────
log_step "7/15 Generating join command"
JOIN_CMD_RAW="$(remote_run "$CP_ID" <(printf 'kubeadm token create --print-join-command\n') "join-command")"
JOIN_COMMAND="$(printf '%s' "$JOIN_CMD_RAW" | tr -d '\r' | grep '^kubeadm join' | tail -n1)"
if [[ -z "$JOIN_COMMAND" ]]; then
  log_fatal "Failed to obtain a join command from the control plane"
fi

# ── 8. Join both workers ──────────────────────────────────────────────────────
log_step "8/15 Joining worker nodes"
for i in "${!WORKER_IDS[@]}"; do
  idx=$((i + 1))
  wid="${WORKER_IDS[$i]}"
  ssm_run_with_env "$wid" "$SCRIPT_DIR/worker-setup.sh" "worker-join-${idx}" \
    NODE_NAME "${WORKER_NAME_PREFIX}-${idx}" \
    JOIN_COMMAND "$JOIN_COMMAND"
  log_ok "Joined: ${WORKER_NAME_PREFIX}-${idx} ($wid)"
done

# ── 9+10. Install Cilium with Hubble enabled ─────────────────────────────────
log_step "9-10/15 Installing Cilium CNI + Hubble"
"$SCRIPT_DIR/install-addons.sh" --only cilium

# ── 11. Wait for all nodes to become Ready ───────────────────────────────────
log_step "11/15 Waiting for nodes to become Ready"
remote_run "$CP_ID" <(cat <<'EOF'
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl wait --for=condition=Ready node --all --timeout=300s
kubectl get nodes -o wide
EOF
) "wait-nodes-ready"

# ── 12. Verify CoreDNS ────────────────────────────────────────────────────────
log_step "12/15 Verifying CoreDNS"
remote_run "$CP_ID" <(cat <<'EOF'
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n kube-system rollout status deployment/coredns --timeout=180s
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
EOF
) "verify-coredns"

# ── 13+14. Cross-node pod connectivity and Service DNS self-test ────────────
log_step "13-14/15 Testing cross-node pod connectivity and Service DNS"
remote_run "$CP_ID" <(cat <<'EOF'
export KUBECONFIG=/etc/kubernetes/admin.conf
NS=ckne-bootstrap-selftest
kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout=120s
kubectl create namespace "$NS"

WORKERS=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')
NODE_A=$(echo $WORKERS | awk '{print $1}')
NODE_B=$(echo $WORKERS | awk '{print $2}')
[ -z "$NODE_B" ] && NODE_B=$NODE_A

kubectl -n "$NS" run selftest-a --image=busybox:1.36 --restart=Never --overrides="{\"spec\":{\"nodeName\":\"$NODE_A\"}}" -- sleep 3600
kubectl -n "$NS" run selftest-b --image=busybox:1.36 --restart=Never --overrides="{\"spec\":{\"nodeName\":\"$NODE_B\"}}" -- sleep 3600
kubectl -n "$NS" expose pod selftest-b --port=80 --target-port=80 --name=selftest-b-svc || true
kubectl -n "$NS" wait --for=condition=Ready pod/selftest-a pod/selftest-b --timeout=120s

POD_B_IP=$(kubectl -n "$NS" get pod selftest-b -o jsonpath='{.status.podIP}')
echo "Cross-node ping test ($NODE_A -> $NODE_B, $POD_B_IP):"
kubectl -n "$NS" exec selftest-a -- ping -c 3 -W 2 "$POD_B_IP"

echo "Service DNS test (selftest-b-svc.$NS.svc.cluster.local):"
kubectl -n "$NS" exec selftest-a -- nslookup "selftest-b-svc.$NS.svc.cluster.local"

kubectl delete namespace "$NS" --wait=true --timeout=120s
echo "Bootstrap self-test namespace cleaned up."
EOF
) "bootstrap-selftest"

# ── 15. Remove temporary join information ────────────────────────────────────
log_step "15/15 Revoking bootstrap token"
JOIN_TOKEN="$(printf '%s' "$JOIN_COMMAND" | grep -oE '\-\-token [a-z0-9]{6}\.[a-z0-9]{16}' | awk '{print $2}')"
if [[ -n "$JOIN_TOKEN" ]]; then
  remote_run "$CP_ID" <(printf 'export KUBECONFIG=/etc/kubernetes/admin.conf\nkubeadm token delete %q || true\n' "$JOIN_TOKEN") "revoke-join-token" >/dev/null || true
  log_info "Bootstrap token revoked."
fi
unset JOIN_COMMAND JOIN_CMD_RAW JOIN_TOKEN

log_ok "Cluster bootstrap complete."
log_info "Next: ./kubeadm-setup/download-kubeconfig.sh   (get kubectl access from your laptop)"
log_info "Then: ./kubeadm-setup/install-addons.sh          (Gateway API, Istio, Prometheus, Jaeger, cert-manager)"
log_info "Then: ./kubeadm-setup/verify-cluster.sh"
