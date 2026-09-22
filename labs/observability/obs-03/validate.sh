#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="OBS-03"
NAMESPACE="ckne-obs-03"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

# Precondition (not the task): Cilium + Hubble relay must be healthy cluster-wide.
CILIUM_DESIRED="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
CILIUM_READY="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$CILIUM_DESIRED" && "$CILIUM_DESIRED" != "0" && "$CILIUM_DESIRED" == "$CILIUM_READY" ]]; then
  ckne_pass "Cilium DaemonSet Ready ($CILIUM_READY/$CILIUM_DESIRED nodes) — precondition"
else
  ckne_fail_check "Cilium DaemonSet not Ready ($CILIUM_READY/$CILIUM_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

WEB_READY="$(kubectl -n "$NAMESPACE" get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${WEB_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment web is 1/1 Ready"
else
  ckne_fail_check "Deployment web is ${WEB_READY:-0}/1 Ready"
  RESULT=1
fi

# Real traffic: client-a (role=allowed) MUST reach web; client-b (role=blocked) must NOT.
ALLOWED_OK=0
if kubectl -n "$NAMESPACE" exec client-a -- wget -q -T 5 -O- "http://web.${NAMESPACE}.svc.cluster.local" >/tmp/obs03-a.out 2>&1; then
  ckne_pass "client-a (role=allowed) can reach web"
  ALLOWED_OK=1
else
  ckne_fail_check "client-a (role=allowed) could NOT reach web — the NetworkPolicy's allow-selector is wrong"
  RESULT=1
fi
rm -f /tmp/obs03-a.out

if kubectl -n "$NAMESPACE" exec client-b -- wget -q -T 5 -O- "http://web.${NAMESPACE}.svc.cluster.local" >/tmp/obs03-b.out 2>&1; then
  ckne_fail_check "client-b (role=blocked) reached web — it must remain denied by the NetworkPolicy"
  RESULT=1
else
  ckne_pass "client-b (role=blocked) is correctly denied"
fi
rm -f /tmp/obs03-b.out

# Real observability check: Hubble must have actually recorded both flows.
# Hubble's per-node buffer only sees flows local to that node, so query every
# cilium agent Pod (loop, don't assume a single node) and combine results.
CILIUM_PODS="$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
if [[ -z "$CILIUM_PODS" ]]; then
  ckne_fail_check "No cilium agent Pods found in kube-system — cannot query Hubble"
  RESULT=1
else
  HUBBLE_OUT=""
  for pod in $CILIUM_PODS; do
    OUT="$(kubectl -n kube-system exec "$pod" -c cilium-agent -- hubble observe --namespace "$NAMESPACE" --last 200 2>/dev/null || \
           kubectl -n kube-system exec "$pod" -- hubble observe --namespace "$NAMESPACE" --last 200 2>/dev/null || true)"
    HUBBLE_OUT="${HUBBLE_OUT}
${OUT}"
  done

  if echo "$HUBBLE_OUT" | grep "client-a" | grep -qi "FORWARDED"; then
    ckne_pass "Hubble shows a FORWARDED flow for client-a -> web (allowed traffic is observable)"
  else
    ckne_fail_check "Hubble shows no FORWARDED flow for client-a -> web"
    RESULT=1
  fi

  if echo "$HUBBLE_OUT" | grep "client-b" | grep -qi "DROPPED"; then
    ckne_pass "Hubble shows a DROPPED flow for client-b -> web (denied traffic is observable)"
  else
    ckne_fail_check "Hubble shows no DROPPED flow for client-b -> web"
    RESULT=1
  fi
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
