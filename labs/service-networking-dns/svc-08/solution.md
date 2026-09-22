# Solution — SVC-08

## Diagnosis

```bash
kubectl -n ckne-svc-08 get svc test-dns -o jsonpath='{.spec.clusterIP}'
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'
```

The `svc08test.example:53` block forwards to `203.0.113.53` (an RFC 5737
TEST-NET address that never answers) instead of `test-dns`'s real
ClusterIP.

## Fix

Edit `kube-system/coredns`, changing only the `forward` line inside the
`svc08test.example:53` block to `test-dns`'s ClusterIP (see
`manifests/expected/corefile-snippet.txt` for the pattern):

```bash
TEST_DNS_IP=$(kubectl -n ckne-svc-08 get svc test-dns -o jsonpath='{.spec.clusterIP}')
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile
sed -i.bak "s/forward . 203.0.113.53/forward . ${TEST_DNS_IP}/" /tmp/Corefile
kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment/coredns
```

## Verify

```bash
kubectl -n ckne-svc-08 run checker --image=busybox:1.36 --restart=Never --rm -it -- nslookup check.svc08test.example    # -> 10.99.99.99
kubectl -n ckne-svc-08 run checker --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes.default.svc.cluster.local  # still works
make validate LAB=SVC-08
```

Only the `svc08test.example` block changed — the `.` zone's
`cluster.local` handling (and everything else in the Corefile) is
byte-for-byte identical to before, which is exactly why normal cluster DNS
was never at risk.
