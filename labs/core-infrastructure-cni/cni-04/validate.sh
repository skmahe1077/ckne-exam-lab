#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="CNI-04"
NAMESPACE="ckne-cni-04"

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

CLIENT_READY="$(kubectl -n "$NAMESPACE" get deployment client -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${CLIENT_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment client is 1/1 Ready"
else
  ckne_fail_check "Deployment client is ${CLIENT_READY:-0}/1 Ready"
  RESULT=1
fi

SERVER_READY_CONTAINERS="$(kubectl -n "$NAMESPACE" get pod server -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' 2>/dev/null | grep -c '^true$' || true)"
if [[ "${SERVER_READY_CONTAINERS:-0}" -ge 2 ]]; then
  ckne_pass "Pod server has both containers Ready ($SERVER_READY_CONTAINERS/2)"
else
  ckne_fail_check "Pod server does not have both containers Ready (${SERVER_READY_CONTAINERS:-0}/2)"
  RESULT=1
fi

if ! kubectl -n "$NAMESPACE" get svc server >/dev/null 2>&1; then
  ckne_fail_check "Service server is missing"
  RESULT=1
fi

# Real runtime behaviour: send actual traffic from client, through the
# Service, to the server Pod, and confirm it actually gets an HTTP response.
CLIENT_POD="$(kubectl -n "$NAMESPACE" get pods -l app=client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"
if [[ -n "$CLIENT_POD" ]]; then
  HTTP_CODE="$(kubectl -n "$NAMESPACE" exec "$CLIENT_POD" -- curl -s -o /dev/null -m 5 -w '%{http_code}' "http://server.${NAMESPACE}.svc.cluster.local:80" 2>/tmp/cni04-checker.out || echo "000")"
  if [[ "$HTTP_CODE" == "200" ]]; then
    ckne_pass "client reaches server via the Service on port 80 (HTTP $HTTP_CODE)"
  else
    ckne_fail_check "client did not get an HTTP 200 from the server Service (got: '$HTTP_CODE')"
    cat /tmp/cni04-checker.out >&2 || true
    RESULT=1
  fi
  rm -f /tmp/cni04-checker.out
else
  ckne_fail_check "Could not determine client Pod name"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
