# Hints — SVC-08

## Level 1

```bash
kubectl -n ckne-svc-08 get svc test-dns -o jsonpath='{.spec.clusterIP}'
kubectl -n kube-system get configmap coredns -o yaml
```

Find the `svc08test.example:53 { ... forward . <ip> }` block. Compare the
`<ip>` it currently forwards to against `test-dns`'s actual ClusterIP.

## Level 2

Edit only that block's `forward` line — leave every other line in the
Corefile untouched, including the `.` zone's `kubernetes cluster.local ...`
line:

```bash
kubectl -n kube-system edit configmap coredns
```

## Level 3

After saving, CoreDNS needs to pick up the change:

```bash
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment/coredns
```

Then verify both the fix and that you didn't break anything else — see
`manifests/expected/corefile-snippet.txt` for the corrected block.
