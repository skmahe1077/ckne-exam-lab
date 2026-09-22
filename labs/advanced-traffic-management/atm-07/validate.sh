#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-07"
NAMESPACE="ckne-atm-07"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0
ckne_require_kubectl

# Precondition: Cilium itself must be healthy cluster-wide.
CILIUM_DESIRED="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
CILIUM_READY="$(kubectl -n kube-system get daemonset cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
if [[ -n "$CILIUM_DESIRED" && "$CILIUM_DESIRED" != "0" && "$CILIUM_DESIRED" == "$CILIUM_READY" ]]; then
  ckne_pass "Cilium DaemonSet Ready ($CILIUM_READY/$CILIUM_DESIRED nodes)"
else
  ckne_fail_check "Cilium DaemonSet not Ready ($CILIUM_READY/$CILIUM_DESIRED) — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

# Precondition (established by setup.sh under the 'clustermesh' lock, not the
# task itself): the clustermesh-apiserver control-plane must be up and Ready.
# NOTE (scope limitation): this only proves the control-plane component is
# deployed and healthy in THIS single cluster — it does not and cannot prove
# actual cross-cluster load-balancing, since no second cluster exists here.
CM_READY="$(kubectl -n kube-system get deployment clustermesh-apiserver -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${CM_READY:-0}" -ge 1 ]]; then
  ckne_pass "clustermesh-apiserver Deployment is Ready ($CM_READY replica(s)) in kube-system"
else
  ckne_fail_check "clustermesh-apiserver Deployment is not Ready in kube-system — run: make start LAB=$TASK_ID"
  RESULT=1
fi

if kubectl -n kube-system get svc clustermesh-apiserver >/dev/null 2>&1; then
  ckne_pass "Service clustermesh-apiserver exists in kube-system"
else
  ckne_fail_check "Service clustermesh-apiserver does not exist in kube-system"
  RESULT=1
fi

# Precondition: the mesh mTLS certificates must be present and well-formed —
# real observable state (each Secret actually contains non-empty
# tls.crt/tls.key/ca.crt), not just "the Secret object exists".
for secret in clustermesh-apiserver-server-cert clustermesh-apiserver-admin-cert clustermesh-apiserver-remote-cert clustermesh-apiserver-local-cert; do
  CRT_LEN="$(kubectl -n kube-system get secret "$secret" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | wc -c | tr -d ' ')"
  KEY_LEN="$(kubectl -n kube-system get secret "$secret" -o jsonpath='{.data.tls\.key}' 2>/dev/null | wc -c | tr -d ' ')"
  CA_LEN="$(kubectl -n kube-system get secret "$secret" -o jsonpath='{.data.ca\.crt}' 2>/dev/null | wc -c | tr -d ' ')"
  if [[ "${CRT_LEN:-0}" -gt 0 && "${KEY_LEN:-0}" -gt 0 && "${CA_LEN:-0}" -gt 0 ]]; then
    ckne_pass "Secret $secret contains non-empty tls.crt, tls.key, and ca.crt"
  else
    ckne_fail_check "Secret $secret is missing or has empty tls.crt/tls.key/ca.crt"
    RESULT=1
  fi
done

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  echo "FAIL"
  exit 1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment pricing -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment pricing is Ready"
else
  ckne_fail_check "Deployment pricing is not Ready (${READY:-0}/1)"
  RESULT=1
fi

# Precondition (not the task): pricing must already be global+shared.
GLOBAL_ANNOTATION="$(kubectl -n "$NAMESPACE" get svc pricing -o jsonpath='{.metadata.annotations.service\.cilium\.io/global}' 2>/dev/null || echo "")"
SHARED_ANNOTATION="$(kubectl -n "$NAMESPACE" get svc pricing -o jsonpath='{.metadata.annotations.service\.cilium\.io/shared}' 2>/dev/null || echo "")"
if [[ "$GLOBAL_ANNOTATION" == "true" && "$SHARED_ANNOTATION" == "true" ]]; then
  ckne_pass "Service pricing is already global+shared (precondition, unchanged)"
else
  ckne_fail_check "Service pricing lost its global/shared annotations (global='${GLOBAL_ANNOTATION:-<missing>}', shared='${SHARED_ANNOTATION:-<missing>}') — these are a precondition, do not remove them"
  RESULT=1
fi

# The task itself: cross-cluster load-balancing affinity must be "local"
# (prefer local-cluster backends, fail over to remote only if local is
# unhealthy). This lab cannot test actual cross-cluster traffic distribution
# with only one real cluster — see concept.md/task.md for the scope
# limitation. What is verified here is that the Service is CORRECTLY
# CONFIGURED to apply that policy the moment a real mesh exists.
AFFINITY_ANNOTATION="$(kubectl -n "$NAMESPACE" get svc pricing -o jsonpath='{.metadata.annotations.service\.cilium\.io/affinity}' 2>/dev/null || echo "")"
if [[ "$AFFINITY_ANNOTATION" == "local" ]]; then
  ckne_pass "Service pricing carries service.cilium.io/affinity=local"
else
  ckne_fail_check "Service pricing does not carry service.cilium.io/affinity=local (got: '${AFFINITY_ANNOTATION:-<missing>}')"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
