#!/usr/bin/env bash
# ==============================================================================
# Shared helpers sourced by every lab's setup.sh / validate.sh / cleanup.sh /
# reset.sh. Do not execute this file directly.
#
# Every lab script that sources this file is expected to first set, as
# readonly constants (never as arguments/user input):
#   TASK_ID="CNI-01"
#   NAMESPACE="ckne-cni-01"
#
# Compatible with bash 3.2 (macOS default) as well as bash 4/5 (Ubuntu nodes)
# — no mapfile/readarray, no associative arrays, no `local -n`.
# ==============================================================================

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ckne_log()   { printf '[%s] %s\n' "${TASK_ID:-ckne}" "$*"; }
ckne_warn()  { printf '[%s] WARN: %s\n' "${TASK_ID:-ckne}" "$*" >&2; }
ckne_fail()  { printf '[%s] ERROR: %s\n' "${TASK_ID:-ckne}" "$*" >&2; exit 1; }

# ckne_require_kubectl — fail fast with a clear message if kubectl has no
# usable context/cluster at all.
ckne_require_kubectl() {
  command -v kubectl >/dev/null 2>&1 || ckne_fail "kubectl not found on PATH. Run: export KUBECONFIG=kubeadm-setup/ckne-cluster.kubeconfig"
  kubectl cluster-info >/dev/null 2>&1 || ckne_fail "kubectl cannot reach a cluster. Run: export KUBECONFIG=kubeadm-setup/ckne-cluster.kubeconfig (see make kubeconfig)"
}

# ckne_require_nodes_ready — validates the expected cluster shape: all nodes
# Ready, and at least one control-plane + one worker node present.
ckne_require_nodes_ready() {
  ckne_require_kubectl
  local not_ready
  not_ready="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1}')"
  if [[ -n "$not_ready" ]]; then
    ckne_fail "Node(s) not Ready: $not_ready — fix the cluster before running labs (make cluster-verify)."
  fi
  local node_count
  node_count="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${node_count:-0}" -lt 2 ]]; then
    ckne_fail "Expected at least 2 nodes (1 control-plane + workers), found ${node_count:-0}. This does not look like the CKNE practice cluster."
  fi
}

# ckne_setup_namespace <namespace> <task-id>
# Deletes any incomplete earlier run of the SAME namespace, waits for it to
# be gone, then (re)creates it with the required labels.
ckne_setup_namespace() {
  local ns="$1" task_id="$2"
  [[ -z "$ns" || -z "$task_id" ]] && ckne_fail "ckne_setup_namespace requires <namespace> <task-id>"
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    ckne_warn "Namespace $ns already exists (incomplete earlier run?) — removing it first."
    kubectl delete namespace "$ns" --wait=true --timeout=120s
  fi
  kubectl create namespace "$ns"
  kubectl label namespace "$ns" \
    app.kubernetes.io/part-of=ckne-hands-on \
    "ckne.openai.com/lab-id=${task_id}" \
    --overwrite
}

# ckne_delete_namespace <namespace>
# Deletes the namespace (idempotent — no error if already gone) and waits.
ckne_delete_namespace() {
  local ns="$1"
  [[ -z "$ns" ]] && ckne_fail "ckne_delete_namespace requires <namespace>"
  kubectl delete namespace "$ns" --ignore-not-found --wait=true --timeout=180s
}

# ckne_verify_namespace_gone <namespace>
# Returns 0 if the namespace does not exist, 1 otherwise. Used by cleanup.sh
# to confirm nothing remains.
ckne_verify_namespace_gone() {
  local ns="$1"
  ! kubectl get namespace "$ns" >/dev/null 2>&1
}

# ckne_wait_pods_ready <namespace> [timeout]
ckne_wait_pods_ready() {
  local ns="$1" timeout="${2:-120s}"
  kubectl -n "$ns" wait --for=condition=Ready pod --all --timeout="$timeout"
}

# ckne_resolve_lab_dir <task-id> — prints the lab directory path for a task
# ID (e.g. "SVC-03" -> ".../labs/service-networking-dns/svc-03"), or nothing
# if not found. Case-insensitive on the task ID.
ckne_resolve_lab_dir() {
  local task_id="$1"
  find "$SHARED_DIR/../labs" -mindepth 2 -maxdepth 2 -type d -iname "$task_id" 2>/dev/null | head -n1
}

# ckne_pass "message" / ckne_fail_check "message" — standard PASS/FAIL output
# for validate.sh. Distinct from ckne_fail (which exits with generic error
# framing) so validators keep a consistent, greppable PASS/FAIL line.
ckne_pass() {
  printf 'PASS: %s\n' "$*"
}
ckne_fail_check() {
  printf 'FAIL: %s\n' "$*"
}
