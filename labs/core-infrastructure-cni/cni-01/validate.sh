#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-01"
NAMESPACE="ckne-cni-01"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0

ckne_require_kubectl

# Precondition (not the task): Cilium itself must be healthy cluster-wide.
CILIUM_DESIRED="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
CILIUM_READY="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$CILIUM_DESIRED" && "$CILIUM_DESIRED" != "0" && "$CILIUM_DESIRED" == "$CILIUM_READY" ]]; then
  ckne_pass "Cilium DaemonSet Ready ($CILIUM_READY/$CILIUM_DESIRED nodes)"
else
  ckne_fail_check "Cilium DaemonSet not Ready ($CILIUM_READY/$CILIUM_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
DESIRED="$(kubectl -n "$NAMESPACE" get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "2" && "$DESIRED" == "2" ]]; then
  ckne_pass "Deployment web is 2/2 Ready"
else
  ckne_fail_check "Deployment web is ${READY:-0}/${DESIRED:-2} Ready"
  RESULT=1
fi

POD_IPS="$(kubectl -n "$NAMESPACE" get pods -l app=web -o jsonpath='{.items[*].status.podIP}')"
BAD_IP=0
for ip in $POD_IPS; do
  case "$ip" in
    10.244.*) ;;
    *) BAD_IP=1 ;;
  esac
done
if [[ -n "$POD_IPS" && "$BAD_IP" -eq 0 ]]; then
  ckne_pass "web Pods have IPs inside 10.244.0.0/16 ($POD_IPS)"
else
  ckne_fail_check "web Pods missing a valid Pod CIDR IP (got: '$POD_IPS')"
  RESULT=1
fi

# Real runtime behaviour check: actually send traffic through the Service.
if kubectl -n "$NAMESPACE" run cni01-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://web.${NAMESPACE}.svc.cluster.local" >/tmp/cni01-checker.out 2>&1; then
  ckne_pass "Service web routes traffic successfully"
else
  ckne_fail_check "Service web did not respond to an in-cluster request"
  cat /tmp/cni01-checker.out >&2 || true
  RESULT=1
fi
rm -f /tmp/cni01-checker.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
