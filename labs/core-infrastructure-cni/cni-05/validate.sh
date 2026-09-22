#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-05"
NAMESPACE="ckne-cni-05"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0

ckne_require_kubectl

# Precondition (not the task): CoreDNS itself must be healthy cluster-wide,
# ruling out a cluster-wide DNS outage before blaming this Pod.
COREDNS_DESIRED="$(kubectl -n kube-system get deployment coredns -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
COREDNS_READY="$(kubectl -n kube-system get deployment coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ -n "$COREDNS_DESIRED" && "$COREDNS_DESIRED" != "0" && "$COREDNS_DESIRED" == "$COREDNS_READY" ]]; then
  ckne_pass "CoreDNS Deployment Ready ($COREDNS_READY/$COREDNS_DESIRED) — not a cluster-wide DNS outage"
else
  ckne_fail_check "CoreDNS Deployment not fully Ready ($COREDNS_READY/$COREDNS_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

SERVER_READY="$(kubectl -n "$NAMESPACE" get deployment server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${SERVER_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment server is 1/1 Ready"
else
  ckne_fail_check "Deployment server is ${SERVER_READY:-0}/1 Ready"
  RESULT=1
fi

CLIENT_PHASE="$(kubectl -n "$NAMESPACE" get pod client -o jsonpath='{.status.phase}' 2>/dev/null || echo "")"
if [[ "$CLIENT_PHASE" == "Running" ]]; then
  ckne_pass "Pod client is Running"
else
  ckne_fail_check "Pod client is not Running (phase: ${CLIENT_PHASE:-unknown})"
  RESULT=1
fi

# Real runtime behaviour: client must actually resolve the in-cluster name.
FQDN="server.${NAMESPACE}.svc.cluster.local"
if kubectl -n "$NAMESPACE" exec client -- nslookup "$FQDN" >/tmp/cni05-nslookup.out 2>&1; then
  ckne_pass "client resolves $FQDN via DNS"
else
  ckne_fail_check "client cannot resolve $FQDN"
  cat /tmp/cni05-nslookup.out >&2 || true
  RESULT=1
fi
rm -f /tmp/cni05-nslookup.out

# Real runtime behaviour: and must actually connect using that name.
if kubectl -n "$NAMESPACE" exec client -- wget -q -T 5 -O- "http://${FQDN}" >/tmp/cni05-wget.out 2>&1; then
  ckne_pass "client connects to $FQDN over HTTP"
else
  ckne_fail_check "client resolves but cannot connect to $FQDN"
  cat /tmp/cni05-wget.out >&2 || true
  RESULT=1
fi
rm -f /tmp/cni05-wget.out

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
