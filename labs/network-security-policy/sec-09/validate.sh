#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-09"
NAMESPACE="ckne-sec-09"
ISSUER_NAME="ckne-sec-09-issuer"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

RESULT=0
ckne_require_kubectl

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

# --- Part A: cert-manager Issuer + Certificate ---

if kubectl -n "$NAMESPACE" get issuer "$ISSUER_NAME" >/dev/null 2>&1; then
  ISSUER_READY="$(kubectl -n "$NAMESPACE" get issuer "$ISSUER_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"
  if [[ "$ISSUER_READY" == "True" ]]; then
    ckne_pass "Issuer $ISSUER_NAME exists and is Ready"
  else
    ckne_fail_check "Issuer $ISSUER_NAME exists but is not Ready (status: '${ISSUER_READY:-<none>}')"
    RESULT=1
  fi
else
  ckne_fail_check "Issuer $ISSUER_NAME not found in $NAMESPACE"
  RESULT=1
fi

CERT_NAME="$(kubectl -n "$NAMESPACE" get certificate -l "ckne.openai.com/lab-id=${TASK_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$CERT_NAME" ]]; then
  ckne_fail_check "No Certificate found in $NAMESPACE labeled ckne.openai.com/lab-id=${TASK_ID}"
  RESULT=1
else
  CERT_READY="$(kubectl -n "$NAMESPACE" get certificate "$CERT_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"
  if [[ "$CERT_READY" == "True" ]]; then
    ckne_pass "Certificate $CERT_NAME reports Ready: True"
  else
    ckne_fail_check "Certificate $CERT_NAME is not Ready (status: '${CERT_READY:-<none>}')"
    RESULT=1
  fi

  SECRET_NAME="$(kubectl -n "$NAMESPACE" get certificate "$CERT_NAME" -o jsonpath='{.spec.secretName}' 2>/dev/null || true)"
  if [[ -z "$SECRET_NAME" ]]; then
    ckne_fail_check "Certificate $CERT_NAME has no spec.secretName set"
    RESULT=1
  else
    CRT_LEN="$(kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | wc -c | tr -d ' ')"
    KEY_LEN="$(kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath='{.data.tls\.key}' 2>/dev/null | wc -c | tr -d ' ')"
    if [[ "${CRT_LEN:-0}" -gt 50 && "${KEY_LEN:-0}" -gt 50 ]]; then
      ckne_pass "Secret $SECRET_NAME contains non-empty tls.crt and tls.key"
    else
      ckne_fail_check "Secret $SECRET_NAME is missing real tls.crt/tls.key data (crt len=${CRT_LEN:-0}, key len=${KEY_LEN:-0})"
      RESULT=1
    fi
  fi
fi

# --- Part B: ServiceAccount identity ---

READY="$(kubectl -n "$NAMESPACE" get deployment backend-workload -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend-workload is Ready"
else
  ckne_fail_check "Deployment backend-workload is not Ready (${READY:-0}/1)"
  RESULT=1
fi

POD_NAME="$(kubectl -n "$NAMESPACE" get pods -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$POD_NAME" ]]; then
  ckne_fail_check "No backend Pod found in $NAMESPACE"
  RESULT=1
else
  SA_NAME="$(kubectl -n "$NAMESPACE" get pod "$POD_NAME" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null || true)"
  if [[ "$SA_NAME" == "backend-identity" ]]; then
    ckne_pass "Pod $POD_NAME runs under serviceAccountName=backend-identity"
  else
    ckne_fail_check "Pod $POD_NAME runs under serviceAccountName='${SA_NAME:-default}', expected backend-identity"
    RESULT=1
  fi

  # Real runtime check: confirm the identity is actually mounted into the running container.
  if kubectl -n "$NAMESPACE" exec "$POD_NAME" -- test -f /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null 2>&1; then
    ckne_pass "Pod $POD_NAME has a mounted ServiceAccount token (identity actually projected into the container)"
  else
    ckne_fail_check "Pod $POD_NAME has no mounted ServiceAccount token"
    RESULT=1
  fi
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
