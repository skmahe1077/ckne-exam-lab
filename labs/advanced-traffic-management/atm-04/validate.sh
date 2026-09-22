#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="ATM-04"
NAMESPACE="ckne-atm-04"
HOSTNAME="atm04.ckne.local"

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

CERT_READY="$(kubectl -n "$NAMESPACE" get certificate ckne-atm-04-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"
if [[ "$CERT_READY" == "True" ]]; then
  ckne_pass "Certificate ckne-atm-04-cert is Ready (precondition)"
else
  ckne_fail_check "Certificate ckne-atm-04-cert is not Ready — this is a precondition, not the task itself"
  RESULT=1
fi

GW_SVC="$(kubectl -n "$NAMESPACE" get svc -l "gateway.networking.k8s.io/gateway-name=atm-gw" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$GW_SVC" ]]; then
  GW_SVC="cilium-gateway-atm-gw"
fi
GW_IP="$(kubectl -n "$NAMESPACE" get svc "$GW_SVC" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")"
if [[ -z "$GW_IP" ]]; then
  ckne_fail_check "Could not find the Gateway's Service ClusterIP (looked for $GW_SVC)"
  echo "FAIL"
  exit 1
fi

kubectl -n "$NAMESPACE" delete pod atm04-checker --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
kubectl -n "$NAMESPACE" run atm04-checker --image=nicolaka/netshoot --restart=Never -- sleep 300 >/dev/null
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/atm04-checker --timeout=60s >/dev/null

TLS_OUT="$(kubectl -n "$NAMESPACE" exec atm04-checker -- \
  openssl s_client -connect "${GW_IP}:443" -servername "$HOSTNAME" </dev/null 2>&1 || true)"
if printf '%s' "$TLS_OUT" | grep -q "CN[[:space:]]*=[[:space:]]*${HOSTNAME}\|CN=${HOSTNAME}"; then
  ckne_pass "TLS handshake succeeds and certificate CN/SAN matches ${HOSTNAME}"
else
  ckne_fail_check "TLS handshake did not present a certificate for ${HOSTNAME}"
  printf '%s\n' "$TLS_OUT" | tail -n 20 >&2
  RESULT=1
fi

HTTP_OUT="$(kubectl -n "$NAMESPACE" exec atm04-checker -- \
  curl -sk --max-time 5 --resolve "${HOSTNAME}:443:${GW_IP}" "https://${HOSTNAME}/" 2>&1 || true)"
if printf '%s' "$HTTP_OUT" | grep -q "atm04-backend"; then
  ckne_pass "HTTPS request through the Gateway reaches the web backend"
else
  ckne_fail_check "HTTPS request did not reach the web backend"
  printf '%s\n' "$HTTP_OUT" >&2
  RESULT=1
fi

kubectl -n "$NAMESPACE" delete pod atm04-checker --ignore-not-found --wait=false >/dev/null 2>&1 || true

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
