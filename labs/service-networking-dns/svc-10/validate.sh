#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-10"
NAMESPACE="ckne-svc-10"
BACKEND_NAMESPACE="ckne-svc-10-backend"
CHECKER_IMAGE="busybox:1.36"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_kubectl

RESULT=0

# Precondition (not the task): the shared GatewayClass must be Accepted.
GWC_ACCEPTED="$(kubectl get gatewayclass cilium -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "")"
if [[ "$GWC_ACCEPTED" == "True" ]]; then
  ckne_pass "GatewayClass 'cilium' is Accepted"
else
  ckne_fail_check "GatewayClass 'cilium' is not Accepted — cluster-level issue, not part of this task's fix"
  RESULT=1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi
if ! kubectl get namespace "$BACKEND_NAMESPACE" >/dev/null 2>&1; then
  ckne_fail_check "Namespace $BACKEND_NAMESPACE does not exist — run: make start LAB=$TASK_ID"
  exit 1
fi

BACKEND_READY="$(kubectl -n "$BACKEND_NAMESPACE" get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${BACKEND_READY:-0}" == "1" ]]; then
  ckne_pass "Deployment backend is 1/1 Ready in $BACKEND_NAMESPACE"
else
  ckne_fail_check "Deployment backend is ${BACKEND_READY:-0}/1 Ready in $BACKEND_NAMESPACE"
  RESULT=1
fi

GW_PROGRAMMED="$(kubectl -n "$NAMESPACE" get gateway svc10-gw -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")"
if [[ "$GW_PROGRAMMED" == "True" ]]; then
  ckne_pass "Gateway svc10-gw is Programmed"
else
  ckne_fail_check "Gateway svc10-gw is not Programmed (status: '${GW_PROGRAMMED:-<missing>}')"
  RESULT=1
fi

# The real fix: the HTTPRoute's cross-namespace backendRef must now resolve.
RESOLVED_REFS="$(kubectl -n "$NAMESPACE" get httproute web-route -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null || echo "")"
if [[ "$RESOLVED_REFS" == "True" ]]; then
  ckne_pass "HTTPRoute web-route reports ResolvedRefs=True (the cross-namespace backendRef is permitted)"
else
  ckne_fail_check "HTTPRoute web-route's ResolvedRefs condition is '${RESOLVED_REFS:-<missing>}', not True — the cross-namespace backendRef into $BACKEND_NAMESPACE is still being rejected"
  RESULT=1
fi

# A ReferenceGrant permitting this must actually exist, in the backend namespace.
RG_COUNT="$(kubectl -n "$BACKEND_NAMESPACE" get referencegrant -o name 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
if [[ "${RG_COUNT:-0}" -ge 1 ]]; then
  ckne_pass "A ReferenceGrant exists in $BACKEND_NAMESPACE ($RG_COUNT found)"
else
  ckne_fail_check "No ReferenceGrant found in $BACKEND_NAMESPACE"
  RESULT=1
fi

# Cilium's Gateway implementation auto-creates a ClusterIP Service named
# cilium-gateway-<gateway-name> for every Gateway it programs.
GW_IP=""
for _ in $(seq 1 15); do
  GW_IP="$(kubectl -n "$NAMESPACE" get svc cilium-gateway-svc10-gw -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")"
  [[ -n "$GW_IP" && "$GW_IP" != "None" ]] && break
  sleep 2
done
if [[ -z "$GW_IP" || "$GW_IP" == "None" ]]; then
  ckne_fail_check "Could not find a ClusterIP for Service cilium-gateway-svc10-gw — is the Gateway healthy?"
  echo "FAIL"
  exit 1
fi

# Real end-to-end check: an HTTP request through the Gateway must reach the
# backend Service living in the OTHER namespace.
FOUND=0
for attempt in 1 2 3 4 5; do
  OUT="$(kubectl -n "$NAMESPACE" run "svc10-checker-$$-$attempt" --image="$CHECKER_IMAGE" --restart=Never --rm -i \
    --command -- wget -q -T 5 -O- "http://${GW_IP}/" 2>/dev/null || true)"
  if printf '%s' "$OUT" | grep -q "svc10-backend"; then
    FOUND=1
    break
  fi
  sleep 3
done
if [[ "$FOUND" -eq 1 ]]; then
  ckne_pass "A real HTTP request through the Gateway reaches the cross-namespace backend"
else
  ckne_fail_check "A real HTTP request through the Gateway did not reach the cross-namespace backend (expected body to contain 'svc10-backend')"
  RESULT=1
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
