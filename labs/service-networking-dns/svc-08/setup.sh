#!/usr/bin/env bash
set -Eeuo pipefail

TASK_ID="SVC-08"
NAMESPACE="ckne-svc-08"
LOCK_RESOURCE="coredns"
COREDNS_IMAGE="coredns/coredns:1.11.3"
BACKUP_CM="svc08-coredns-backup"
LOCK_NS="ckne-lab-system"

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LAB_DIR/../../.." && pwd)"
# shellcheck source=../../../shared/scripts/lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

ckne_require_nodes_ready
ckne_setup_namespace "$NAMESPACE" "$TASK_ID"

ckne_log "Acquiring shared lock on '$LOCK_RESOURCE' (CoreDNS is cluster-wide)"
"$REPO_ROOT/shared/scripts/lock.sh" acquire "$LOCK_RESOURCE" "$TASK_ID"

ckne_log "Deploying self-hosted test resolver (test-dns) in $NAMESPACE"
sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" -e "s/\${TASK_ID}/${TASK_ID}/g" -e "s|\${COREDNS_IMAGE}|${COREDNS_IMAGE}|g" \
  "$LAB_DIR/manifests/base/test-dns.yaml" | kubectl apply -f -
kubectl -n "$NAMESPACE" rollout status deployment/test-dns --timeout=120s

TEST_DNS_IP="$(kubectl -n "$NAMESPACE" get svc test-dns -o jsonpath='{.spec.clusterIP}')"
[[ -z "$TEST_DNS_IP" ]] && ckne_fail "Could not determine test-dns ClusterIP"
ckne_log "test-dns ClusterIP: $TEST_DNS_IP"

ckne_log "Backing up the current kube-system/coredns Corefile to $LOCK_NS/$BACKUP_CM"
ORIGINAL_COREFILE="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}')"
[[ -z "$ORIGINAL_COREFILE" ]] && ckne_fail "Could not read the current CoreDNS Corefile"
kubectl -n "$LOCK_NS" create configmap "$BACKUP_CM" \
  --from-literal=Corefile="$ORIGINAL_COREFILE" \
  --dry-run=client -o yaml | kubectl apply -f -

ckne_log "Injecting the (intentionally broken) svc08test.example forward block"
BROKEN_SNIPPET="$(cat "$LAB_DIR/manifests/broken/corefile-snippet.txt")"
NEW_COREFILE="${ORIGINAL_COREFILE}
${BROKEN_SNIPPET}"
kubectl -n kube-system create configmap coredns \
  --from-literal=Corefile="$NEW_COREFILE" \
  --dry-run=client -o yaml | kubectl apply -f -

ckne_log "Restarting CoreDNS to pick up the change"
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=120s

ckne_log "Setup complete. svc08test.example currently forwards to the wrong address (203.0.113.53) — that is the task."
ckne_log "Validate with: make validate LAB=$TASK_ID"
