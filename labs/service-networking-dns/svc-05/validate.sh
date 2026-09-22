#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-05"
NAMESPACE="ckne-svc-05"

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

READY="$(kubectl -n "$NAMESPACE" get statefulset web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
if [[ "${READY:-0}" == "3" ]]; then
  ckne_pass "StatefulSet web is 3/3 Ready"
else
  ckne_fail_check "StatefulSet web is ${READY:-0}/3 Ready"
  RESULT=1
fi

CLUSTER_IP="$(kubectl -n "$NAMESPACE" get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
if [[ "$CLUSTER_IP" == "None" ]]; then
  ckne_pass "Service web is headless (clusterIP: None)"
else
  ckne_fail_check "Service web.spec.clusterIP is '$CLUSTER_IP', expected 'None'"
  RESULT=1
fi

# Real runtime behaviour check: each StatefulSet Pod must have its own
# resolvable DNS record pointing at ITS OWN Pod IP, not a shared VIP.
for i in 0 1 2; do
  POD_NAME="web-$i"
  POD_IP="$(kubectl -n "$NAMESPACE" get pod "$POD_NAME" -o jsonpath='{.status.podIP}' 2>/dev/null || true)"
  if [[ -z "$POD_IP" ]]; then
    ckne_fail_check "Pod $POD_NAME has no PodIP (not Running?)"
    RESULT=1
    continue
  fi

  FQDN="${POD_NAME}.web.${NAMESPACE}.svc.cluster.local"
  if kubectl -n "$NAMESPACE" run "svc05-checker-$i" --image=busybox:1.36 --restart=Never --rm -i \
      --command -- nslookup "$FQDN" >"/tmp/svc05-checker-$i.out" 2>&1; then
    RESOLVED_IP="$(awk '/^Name:/{f=1;next} f && /^Address/{print $2; exit}' "/tmp/svc05-checker-$i.out")"
    if [[ "$RESOLVED_IP" == "$POD_IP" ]]; then
      ckne_pass "$FQDN resolves to $POD_NAME's own IP ($POD_IP)"
    else
      ckne_fail_check "$FQDN resolved to '${RESOLVED_IP:-<none>}', expected $POD_NAME's own IP ($POD_IP)"
      RESULT=1
    fi
  else
    ckne_fail_check "nslookup of $FQDN failed"
    cat "/tmp/svc05-checker-$i.out" >&2 || true
    RESULT=1
  fi
  rm -f "/tmp/svc05-checker-$i.out"
done

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
