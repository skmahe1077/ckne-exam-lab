# Solution — CNI-05

## Diagnosis

1. CoreDNS is healthy cluster-wide:

   ```bash
   kubectl -n kube-system get deployment coredns
   # READY == desired replicas
   ```

   This rules out a cluster-wide outage — the problem must be specific to
   `client`.

2. `client` fails to resolve anything, including `server`'s own Service
   name:

   ```bash
   kubectl -n ckne-cni-05 exec client -- nslookup server.ckne-cni-05.svc.cluster.local
   ```

3. Inspecting the Pod spec shows the actual cause:

   ```bash
   kubectl -n ckne-cni-05 get pod client -o yaml | grep -A5 dnsPolicy
   ```

   `dnsPolicy: None` with a `dnsConfig.nameservers` pointing at
   `192.0.2.53` — a TEST-NET-1 address that never answers. This completely
   bypasses CoreDNS for this Pod only.

## Fix

`dnsPolicy`/`dnsConfig` are immutable once a Pod is created, so the Pod must
be recreated without the override (see
`manifests/expected/client.yaml`):

```bash
kubectl -n ckne-cni-05 delete pod client
kubectl -n ckne-cni-05 run client --image=busybox:1.36 --restart=Never \
  --command -- sh -c "sleep 3600"
```

## Verify

```bash
kubectl -n ckne-cni-05 exec client -- nslookup server.ckne-cni-05.svc.cluster.local
kubectl -n ckne-cni-05 exec client -- wget -q -T5 -O- http://server.ckne-cni-05.svc.cluster.local
make validate LAB=CNI-05
```

CoreDNS was never the problem — the fix is entirely in `client`'s own Pod
spec.
