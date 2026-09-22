# Solution — CNI-02

## Diagnosis

1. Both Deployments report Ready, so the Pods themselves are healthy —
   the problem is in what's allowed to reach `server`:

   ```bash
   kubectl -n ckne-cni-02 get pods -o wide
   kubectl -n ckne-cni-02 get networkpolicy allow-server-ingress -o yaml
   ```

2. The policy allows ingress to `server` only from `ipBlock.cidr:
   172.20.0.0/16`.

3. Real Pod IPs in this cluster (and every namespace) are drawn from
   `10.244.0.0/16` — the `podSubnet` configured at cluster bootstrap. The
   `client` Pod's IP (and every other Pod IP) falls inside `10.244.0.0/16`,
   never inside `172.20.0.0/16` — so the policy's `ipBlock` rule can never
   match real traffic, and everything to `server` is dropped.

## Fix

Correct the `ipBlock.cidr` to the cluster's actual Pod CIDR (see
`manifests/expected/networkpolicy.yaml` for the full corrected object):

```bash
kubectl -n ckne-cni-02 patch networkpolicy allow-server-ingress --type=json \
  -p '[{"op":"replace","path":"/spec/ingress/0/from/0/ipBlock/cidr","value":"10.244.0.0/16"}]'
```

## Verify

```bash
SERVER_IP=$(kubectl -n ckne-cni-02 get pods -l app=server -o jsonpath='{.items[0].status.podIP}')
CLIENT_POD=$(kubectl -n ckne-cni-02 get pods -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl -n ckne-cni-02 exec "$CLIENT_POD" -- wget -q -T 5 -O- "http://${SERVER_IP}:80"
make validate LAB=CNI-02
```

The NetworkPolicy object was never invalid YAML and applied cleanly — the
bug was purely semantic: an `ipBlock` that could never match any real Pod
IP the cluster's IPAM would ever hand out.
