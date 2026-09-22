#!/usr/bin/env bash
# ==============================================================================
# Shared-resource lock, backed by a ConfigMap per resource in the
# ckne-lab-system namespace. Used by any lab that modifies a shared or
# cluster-scoped resource (CoreDNS, Cilium, kube-proxy, GatewayClass, Istio
# control plane, cluster-wide certificates, cluster-scoped RBAC — see
# docs/syllabus-mapping.md).
#
# Design rule: acquire NEVER auto-steals an expired lock — "Do not override
# an active lock automatically" is a hard requirement. A stale lock can only
# be cleared by a human via `make release-stale-lock LAB=<lab-id>`.
#
# Usage:
#   lock.sh acquire <resource> <lab-id> [ttl-seconds, default 3600]
#   lock.sh release <resource> <lab-id>
#   lock.sh release-lab <lab-id>      # force-release every lock held by lab-id
#   lock.sh list
#   lock.sh status <resource>
# ==============================================================================
set -Eeuo pipefail

LOCK_NAMESPACE="ckne-lab-system"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ensure_namespace() {
  kubectl get namespace "$LOCK_NAMESPACE" >/dev/null 2>&1 || \
    kubectl create namespace "$LOCK_NAMESPACE" >/dev/null
}

cm_name() { printf 'ckne-lock-%s' "$1"; }

cmd_acquire() {
  local resource="$1" lab_id="$2" ttl="${3:-3600}"
  [[ -z "$resource" || -z "$lab_id" ]] && fail "acquire requires <resource> <lab-id>"
  ensure_namespace
  local name; name="$(cm_name "$resource")"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if kubectl -n "$LOCK_NAMESPACE" get configmap "$name" >/dev/null 2>&1; then
    local holder
    holder="$(kubectl -n "$LOCK_NAMESPACE" get configmap "$name" -o jsonpath='{.data.holder}')"
    if [[ "$holder" == "$lab_id" ]]; then
      # Idempotent re-acquire by the same lab: refresh renew time.
      kubectl -n "$LOCK_NAMESPACE" patch configmap "$name" --type merge \
        -p "{\"data\":{\"renewed-at\":\"${now}\"}}" >/dev/null
      echo "Lock '$resource' already held by $lab_id — renewed."
      return 0
    fi
    local acquired_at
    acquired_at="$(kubectl -n "$LOCK_NAMESPACE" get configmap "$name" -o jsonpath='{.data.acquired-at}')"
    fail "Lock '$resource' is held by '$holder' (since $acquired_at). Refusing to override an active lock. If you are certain $holder is stale/abandoned, a human must run: make release-stale-lock LAB=$holder"
  fi

  kubectl -n "$LOCK_NAMESPACE" create configmap "$name" \
    --from-literal=holder="$lab_id" \
    --from-literal=resource="$resource" \
    --from-literal=acquired-at="$now" \
    --from-literal=renewed-at="$now" \
    --from-literal=ttl-seconds="$ttl" >/dev/null
  echo "Lock '$resource' acquired by $lab_id"
}

cmd_release() {
  local resource="$1" lab_id="$2"
  [[ -z "$resource" || -z "$lab_id" ]] && fail "release requires <resource> <lab-id>"
  ensure_namespace
  local name; name="$(cm_name "$resource")"
  if ! kubectl -n "$LOCK_NAMESPACE" get configmap "$name" >/dev/null 2>&1; then
    echo "Lock '$resource' already free — nothing to release."
    return 0
  fi
  local holder
  holder="$(kubectl -n "$LOCK_NAMESPACE" get configmap "$name" -o jsonpath='{.data.holder}')"
  if [[ "$holder" != "$lab_id" ]]; then
    echo "WARN: lock '$resource' is held by '$holder', not '$lab_id' — not releasing it." >&2
    return 0
  fi
  kubectl -n "$LOCK_NAMESPACE" delete configmap "$name" --ignore-not-found >/dev/null
  echo "Lock '$resource' released by $lab_id"
}

cmd_release_lab() {
  local lab_id="$1"
  [[ -z "$lab_id" ]] && fail "release-lab requires <lab-id>"
  ensure_namespace
  local names
  names="$(kubectl -n "$LOCK_NAMESPACE" get configmap -o name 2>/dev/null | grep '^configmap/ckne-lock-' || true)"
  local released=0
  for cm in $names; do
    local holder
    holder="$(kubectl -n "$LOCK_NAMESPACE" get "$cm" -o jsonpath='{.data.holder}' 2>/dev/null || true)"
    if [[ "$holder" == "$lab_id" ]]; then
      kubectl -n "$LOCK_NAMESPACE" delete "$cm" --ignore-not-found >/dev/null
      echo "Released: $cm (was held by $lab_id)"
      released=$((released + 1))
    fi
  done
  if [[ "$released" -eq 0 ]]; then
    echo "No locks found held by $lab_id."
  fi
}

cmd_list() {
  ensure_namespace
  local names
  names="$(kubectl -n "$LOCK_NAMESPACE" get configmap -o name 2>/dev/null | grep '^configmap/ckne-lock-' || true)"
  if [[ -z "$names" ]]; then
    echo "No active locks."
    return 0
  fi
  printf '%-25s %-12s %-25s %-8s %s\n' "RESOURCE" "HOLDER" "ACQUIRED-AT" "TTL(s)" "STATE"
  local now_epoch; now_epoch="$(date -u +%s)"
  for cm in $names; do
    local resource holder acquired_at ttl acquired_epoch age state
    resource="$(kubectl -n "$LOCK_NAMESPACE" get "$cm" -o jsonpath='{.data.resource}')"
    holder="$(kubectl -n "$LOCK_NAMESPACE" get "$cm" -o jsonpath='{.data.holder}')"
    acquired_at="$(kubectl -n "$LOCK_NAMESPACE" get "$cm" -o jsonpath='{.data.acquired-at}')"
    ttl="$(kubectl -n "$LOCK_NAMESPACE" get "$cm" -o jsonpath='{.data.ttl-seconds}')"
    acquired_epoch="$(date -u -d "$acquired_at" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$acquired_at" +%s 2>/dev/null || echo "$now_epoch")"
    age=$(( now_epoch - acquired_epoch ))
    state="active"
    [[ -n "$ttl" && "$age" -gt "$ttl" ]] && state="STALE"
    printf '%-25s %-12s %-25s %-8s %s\n' "$resource" "$holder" "$acquired_at" "$ttl" "$state"
  done
}

cmd_status() {
  local resource="$1"
  [[ -z "$resource" ]] && fail "status requires <resource>"
  ensure_namespace
  local name; name="$(cm_name "$resource")"
  if kubectl -n "$LOCK_NAMESPACE" get configmap "$name" >/dev/null 2>&1; then
    kubectl -n "$LOCK_NAMESPACE" get configmap "$name" -o jsonpath='{.data.holder}'
    echo ""
    return 1
  fi
  echo "free"
  return 0
}

case "${1:-}" in
  acquire)      shift; cmd_acquire "$@" ;;
  release)      shift; cmd_release "$@" ;;
  release-lab)  shift; cmd_release_lab "$@" ;;
  list)         shift; cmd_list "$@" ;;
  status)       shift; cmd_status "$@" ;;
  *)
    echo "Usage: $0 {acquire <resource> <lab-id> [ttl]|release <resource> <lab-id>|release-lab <lab-id>|list|status <resource>}" >&2
    exit 1
    ;;
esac
