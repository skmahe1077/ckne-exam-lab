# CKNE-SVC-08 — Solution

## Root cause

The shared CoreDNS Corefile's `svc08test.example:53` server block forwards to `203.0.113.53` — an RFC 5737 TEST-NET address that never answers — instead of the `test-dns` Service's real ClusterIP in `ckne-svc-08`.

## Investigation process

```bash
kubectl -n ckne-svc-08 get svc test-dns -o jsonpath='{.spec.clusterIP}'
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'
```

Find the `svc08test.example:53 { ... forward . <ip> }` block. `<ip>` is `203.0.113.53`, not `test-dns`'s actual ClusterIP.

## Corrected configuration

```
svc08test.example:53 {
    errors
    forward . <test-dns ClusterIP>
}
```

Only this block's `forward` line changes — everything else in the Corefile, including the `.` zone's `kubernetes cluster.local ...` handling, stays byte-for-byte identical:

```bash
TEST_DNS_IP=$(kubectl -n ckne-svc-08 get svc test-dns -o jsonpath='{.spec.clusterIP}')
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile
sed -i.bak "s/forward . 203.0.113.53/forward . ${TEST_DNS_IP}/" /tmp/Corefile
kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment/coredns
```

## Verification steps

```bash
kubectl -n ckne-svc-08 run checker --image=busybox:1.36 --restart=Never --rm -it -- nslookup check.svc08test.example    # -> 10.99.99.99
kubectl -n ckne-svc-08 run checker --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes.default.svc.cluster.local  # still works
make validate LAB=SVC-08
```

## Why this works

CoreDNS matches an incoming query's name against the *most specific* zone it has a server block for, then runs that block's plugin chain — a scoped server block like `svc08test.example:53` is a separate, self-contained zone that only ever handles queries under that exact domain, leaving the `.` block (and its `kubernetes cluster.local` handling) completely untouched. Correcting only the `forward` target inside the `svc08test.example` block is what redirects queries for that zone to the real `test-dns` resolver, while every other query — including all of `cluster.local` — continues to flow through the unmodified `.` block exactly as before. This is precisely why a scoped addition/correction is the safe way to extend CoreDNS: because it's structurally isolated from the base config, it cannot accidentally break cluster-wide DNS the way editing or replacing the `.` block itself could.

## Faster exam-oriented method

`kubectl get configmap coredns -o jsonpath='{.data.Corefile}' -n kube-system | grep -A3 svc08test` to see the block directly, then a single `sed` substitution of the `forward` IP followed by `rollout restart deployment coredns` for an immediate reload (rather than waiting on the `reload` plugin's ~1-minute auto-detection).

## Common mistakes

- Editing or replacing the `.` server block, or touching the `kubernetes cluster.local ...` line — this is a single, cluster-wide ConfigMap shared by every namespace and every other lab; any change beyond the scoped `svc08test.example` block risks breaking DNS resolution for the entire cluster.
- Replacing the whole ConfigMap instead of patching just the `forward` value inside the existing block — a full replacement risks silently dropping other configuration if not done carefully, when a targeted edit is all that's required.
- Forgetting that a ConfigMap edit alone doesn't immediately take effect — either wait for the `reload` plugin's auto-detection (up to ~a minute) or explicitly `rollout restart deployment coredns` for an immediate pickup.
- Verifying only that `check.svc08test.example` resolves without also confirming `kubernetes.default.svc.cluster.local` still works — the task specifically requires proving normal cluster DNS wasn't broken, not just that the new zone works.

## Relevant documentation

- CoreDNS Corefile configuration — https://coredns.io/manual/toc/#configuration
- CoreDNS forward plugin — https://coredns.io/plugins/forward/
- Custom DNS in Kubernetes — https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
- Kubernetes CoreDNS administration — https://kubernetes.io/docs/tasks/administer-cluster/coredns/
