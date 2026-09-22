# Solution — CNI-03

## Diagnosis

1. Routing inside `toolbox` is normal:

   ```bash
   kubectl -n ckne-cni-03 exec toolbox -- ip addr
   kubectl -n ckne-cni-03 exec toolbox -- ip route
   # eth0 has an address in 10.244.0.0/16, default route via the Pod's gateway
   ```

2. `toolbox`'s own `OUTPUT` chain has an explicit `DROP` for outbound
   tcp/80, added by the `break-network` initContainer at Pod startup:

   ```bash
   kubectl -n ckne-cni-03 exec toolbox -- iptables -L OUTPUT -n -v --line-numbers
   # ... DROP  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:80
   ```

   This is entirely local to `toolbox`'s own network namespace — it has
   nothing to do with Cilium, the node, or the `server` Pod.

## Fix

Remove just that rule (see `manifests/expected/toolbox.yaml` for what the
Pod would look like if the rule had never been injected):

```bash
kubectl -n ckne-cni-03 exec toolbox -- iptables -D OUTPUT -p tcp --dport 80 -j DROP
```

## Verify

```bash
kubectl -n ckne-cni-03 exec toolbox -- iptables -L OUTPUT -n -v
kubectl -n ckne-cni-03 exec toolbox -- curl -s -o /dev/null -w '%{http_code}\n' \
  http://server.ckne-cni-03.svc.cluster.local
make validate LAB=CNI-03
```

The fix is entirely inside one Pod's network namespace — no node, no
Cilium configuration, and no other Pod was touched.
