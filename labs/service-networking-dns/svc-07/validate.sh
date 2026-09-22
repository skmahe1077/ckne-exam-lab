#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-07"
NAMESPACE="ckne-svc-07"
CHECKER_IMAGE="nicolaka/netshoot:latest"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0

ckne_require_kubectl

# Precondition (not the task): kube-proxy itself must be healthy cluster-wide,
# and running in iptables mode, as this environment is documented to run.
KP_DESIRED="$(kubectl -n kube-system get daemonset kube-proxy -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
KP_READY="$(kubectl -n kube-system get daemonset kube-proxy -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$KP_DESIRED" && "$KP_DESIRED" != "0" && "$KP_DESIRED" == "$KP_READY" ]]; then
  ckne_pass "kube-proxy DaemonSet Ready ($KP_READY/$KP_DESIRED nodes)"
else
  ckne_fail_check "kube-proxy DaemonSet not Ready ($KP_READY/$KP_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

# Service must exist, be ClusterIP, and select the web Pods on port 80.
SVC_TYPE="$(kubectl -n "$NAMESPACE" get service web -o jsonpath='{.spec.type}' 2>/dev/null || true)"
SVC_SELECTOR="$(kubectl -n "$NAMESPACE" get service web -o jsonpath='{.spec.selector.app}' 2>/dev/null || true)"
SVC_PORT="$(kubectl -n "$NAMESPACE" get service web -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
CLUSTER_IP="$(kubectl -n "$NAMESPACE" get service web -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
if [[ "${SVC_TYPE:-}" == "ClusterIP" && "${SVC_SELECTOR:-}" == "web" && "${SVC_PORT:-}" == "80" && -n "${CLUSTER_IP:-}" && "$CLUSTER_IP" != "None" ]]; then
  ckne_pass "Service web is ClusterIP, selects app=web, exposes port 80 (ClusterIP: $CLUSTER_IP)"
else
  ckne_fail_check "Service web is missing or misconfigured (type='${SVC_TYPE:-}', selector.app='${SVC_SELECTOR:-}', port='${SVC_PORT:-}', clusterIP='${CLUSTER_IP:-}')"
  RESULT=1
fi

# Endpoints must list both web Pod IPs.
EP_COUNT="$(kubectl -n "$NAMESPACE" get endpoints web -o jsonpath='{range .subsets[*]}{range .addresses[*]}{.ip}{"\n"}{end}{end}' 2>/dev/null | grep -c . || true)"
if [[ "${EP_COUNT:-0}" -eq 2 ]]; then
  ckne_pass "Service web has 2 ready Endpoints"
else
  ckne_fail_check "Service web has ${EP_COUNT:-0} ready Endpoints (expected 2) — check the Service's selector against the web Deployment's Pod labels"
  RESULT=1
fi

# Real, verifiable artifact: read the NODE's actual iptables rules (not a
# Pod's own netns) via a throwaway hostNetwork + NET_ADMIN/NET_RAW debug
# Pod, and confirm kube-proxy really programmed a rule for this ClusterIP.
if [[ -n "${CLUSTER_IP:-}" && "$CLUSTER_IP" != "None" ]]; then
  OVERRIDES="{\"spec\":{\"hostNetwork\":true,\"restartPolicy\":\"Never\",\"containers\":[{\"name\":\"svc07-iptables-checker\",\"image\":\"${CHECKER_IMAGE}\",\"command\":[\"sh\",\"-c\",\"iptables-save 2>/dev/null | grep -F ${CLUSTER_IP} || true\"],\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\",\"NET_RAW\"]}}}]}}"

  kubectl -n "$NAMESPACE" run svc07-iptables-checker --image="$CHECKER_IMAGE" --restart=Never --rm -i \
    --overrides="$OVERRIDES" >/tmp/svc07-iptables.out 2>&1 || true

  if grep -qF "$CLUSTER_IP" /tmp/svc07-iptables.out 2>/dev/null; then
    ckne_pass "Node iptables rules (kube-proxy-programmed) reference Service web's ClusterIP ($CLUSTER_IP)"
  else
    ckne_fail_check "No node iptables rule found referencing ClusterIP $CLUSTER_IP — inspect: kubectl -n $NAMESPACE run debug --image=$CHECKER_IMAGE --restart=Never --rm -i --overrides='{\"spec\":{\"hostNetwork\":true,...}}' -- iptables-save"
    cat /tmp/svc07-iptables.out >&2 || true
    RESULT=1
  fi
  rm -f /tmp/svc07-iptables.out
else
  ckne_fail_check "Cannot check iptables rules — Service web has no ClusterIP"
  RESULT=1
fi

# Real runtime behaviour check: actually send traffic through the Service.
if kubectl -n "$NAMESPACE" run svc07-checker --image=busybox:1.36 --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://web.${NAMESPACE}.svc.cluster.local" >/tmp/svc07-checker.out 2>&1; then
  ckne_pass "Service web routes traffic successfully end-to-end"
else
  ckne_fail_check "Service web did not respond to an in-cluster request"
  cat /tmp/svc07-checker.out >&2 || true
  RESULT=1
fi
rm -f /tmp/svc07-checker.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
