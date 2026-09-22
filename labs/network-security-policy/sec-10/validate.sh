#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SEC-10"
NAMESPACE="ckne-sec-10"

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

INJECTION_LABEL="$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || true)"
if [[ "$INJECTION_LABEL" == "enabled" ]]; then
  ckne_pass "$NAMESPACE carries istio-injection=enabled (precondition)"
else
  ckne_fail_check "$NAMESPACE is missing istio-injection=enabled — this is a precondition, do not remove it"
  RESULT=1
fi

READY="$(kubectl -n "$NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is Ready"
else
  ckne_fail_check "Deployment backend is not Ready (${READY:-0}/1) — this is a precondition, fix the environment first"
  RESULT=1
fi

# --- PeerAuthentication ---

PA_NAME="$(kubectl -n "$NAMESPACE" get peerauthentication -l "ckne.openai.com/lab-id=${TASK_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$PA_NAME" ]]; then
  ckne_fail_check "No PeerAuthentication found in $NAMESPACE labeled ckne.openai.com/lab-id=${TASK_ID}"
  RESULT=1
else
  MODE="$(kubectl -n "$NAMESPACE" get peerauthentication "$PA_NAME" -o jsonpath='{.spec.mtls.mode}' 2>/dev/null || true)"
  if [[ "$MODE" == "STRICT" ]]; then
    ckne_pass "PeerAuthentication $PA_NAME has mtls.mode=STRICT"
  else
    ckne_fail_check "PeerAuthentication $PA_NAME has mtls.mode='${MODE:-<unset>}', expected STRICT"
    RESULT=1
  fi
fi

# --- AuthorizationPolicy ---

AP_NAME="$(kubectl -n "$NAMESPACE" get authorizationpolicy -l "ckne.openai.com/lab-id=${TASK_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$AP_NAME" ]]; then
  ckne_fail_check "No AuthorizationPolicy found in $NAMESPACE labeled ckne.openai.com/lab-id=${TASK_ID}"
  RESULT=1
else
  PRINCIPALS="$(kubectl -n "$NAMESPACE" get authorizationpolicy "$AP_NAME" -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}' 2>/dev/null || true)"
  if printf '%s' "$PRINCIPALS" | grep -q "sa/trusted-caller-sa"; then
    ckne_pass "AuthorizationPolicy $AP_NAME allows the trusted-caller-sa principal"
  else
    ckne_fail_check "AuthorizationPolicy $AP_NAME does not list a principal for trusted-caller-sa (got: '${PRINCIPALS:-<none>}')"
    RESULT=1
  fi
fi

# --- Real traffic ---

URL="http://backend.${NAMESPACE}.svc.cluster.local"

CODE="$(kubectl -n "$NAMESPACE" exec trusted-caller -c client -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo 000)"
if [[ "$CODE" == "200" ]]; then
  ckne_pass "trusted-caller (trusted-caller-sa) can reach backend (HTTP 200)"
else
  ckne_fail_check "trusted-caller could NOT reach backend (got HTTP $CODE) — it is the one identity that should be allowed"
  RESULT=1
fi

CODE="$(kubectl -n "$NAMESPACE" exec untrusted-caller -c client -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo 000)"
if [[ "$CODE" == "200" ]]; then
  ckne_fail_check "untrusted-caller (untrusted-caller-sa) reached backend (HTTP 200) — the AuthorizationPolicy must deny mesh identities other than trusted-caller-sa"
  RESULT=1
else
  ckne_pass "untrusted-caller is correctly denied (got HTTP $CODE)"
fi

CODE="$(kubectl -n "$NAMESPACE" exec no-mesh-caller -c client -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo 000)"
if [[ "$CODE" == "200" ]]; then
  ckne_fail_check "no-mesh-caller (no sidecar, plaintext) reached backend (HTTP 200) — STRICT mTLS must reject non-mTLS connections"
  RESULT=1
else
  ckne_pass "no-mesh-caller is correctly denied (got HTTP $CODE)"
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
