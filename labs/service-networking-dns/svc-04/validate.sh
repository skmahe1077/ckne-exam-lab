#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-04"
NAMESPACE="ckne-svc-04"

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

if ! kubectl -n "$NAMESPACE" get svc docs >/dev/null 2>&1; then
  ckne_fail_check "Service docs does not exist in $NAMESPACE"
  echo "FAIL"
  exit 1
fi

SVC_TYPE="$(kubectl -n "$NAMESPACE" get svc docs -o jsonpath='{.spec.type}' 2>/dev/null || true)"
if [[ "$SVC_TYPE" == "ExternalName" ]]; then
  ckne_pass "Service docs is type ExternalName"
else
  ckne_fail_check "Service docs has type '$SVC_TYPE', expected ExternalName"
  RESULT=1
fi

EXT_NAME="$(kubectl -n "$NAMESPACE" get svc docs -o jsonpath='{.spec.externalName}' 2>/dev/null || true)"
case "$EXT_NAME" in
  *nonexistent-ckne-lab-domain*|"")
    ckne_fail_check "Service docs.spec.externalName ('$EXT_NAME') is still the broken placeholder domain"
    RESULT=1
    ;;
  *)
    ckne_pass "Service docs.spec.externalName is set to '$EXT_NAME'"
    ;;
esac

# Real runtime behaviour check: actually resolve the Service's DNS name from
# inside the cluster and confirm CoreDNS's CNAME rewrite reaches the
# configured external name (this IS the entire mechanism of ExternalName —
# there is no data-plane/proxy behaviour to test separately).
if [[ "$RESULT" -eq 0 ]]; then
  if kubectl -n "$NAMESPACE" run svc04-checker --image=busybox:1.36 --restart=Never --rm -i \
      --command -- nslookup "docs.${NAMESPACE}.svc.cluster.local" >/tmp/svc04-checker.out 2>&1; then
    if grep -qi "$EXT_NAME" /tmp/svc04-checker.out && ! grep -qi "can't find\|NXDOMAIN\|SERVFAIL" /tmp/svc04-checker.out; then
      ckne_pass "docs.${NAMESPACE}.svc.cluster.local resolves via CoreDNS CNAME to $EXT_NAME"
    else
      ckne_fail_check "nslookup succeeded but did not return a CNAME/records for $EXT_NAME"
      cat /tmp/svc04-checker.out >&2 || true
      RESULT=1
    fi
  else
    ckne_fail_check "nslookup of docs.${NAMESPACE}.svc.cluster.local failed"
    cat /tmp/svc04-checker.out >&2 || true
    RESULT=1
  fi
  rm -f /tmp/svc04-checker.out
else
  ckne_fail_check "Skipping DNS resolution check because the Service is not correctly configured yet"
fi

if [[ "$RESULT" -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$RESULT"
