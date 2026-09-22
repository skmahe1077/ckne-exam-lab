# Solution — CNI-06

## Diagnosis

`multi-iface-app` runs two containers (`data-plane` on 8080, `mgmt-plane` on
9090) in a single Pod, which — as confirmed by `status.podIPs` having exactly
one entry — has only one real network interface. There is no `NetworkPolicy`
yet, so both `client` and `admin-client` can currently reach both
`data-svc` (8080) and `mgmt-svc` (9090). The management plane needs to be
restricted to `role: admin` Pods only.

## Fix

Apply a single `NetworkPolicy` with two per-port ingress rules
(`manifests/expected/networkpolicy.yaml`):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-iface-per-port
  namespace: ckne-cni-06
spec:
  podSelector:
    matchLabels:
      app: multi-iface-app
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - protocol: TCP
          port: 8080
    - from:
        - podSelector:
            matchLabels:
              role: admin
      ports:
        - protocol: TCP
          port: 9090
```

```bash
kubectl apply -f labs/core-infrastructure-cni/cni-06/manifests/expected/networkpolicy.yaml
```

The first ingress rule has no `from` at all, so it allows traffic from any
source in the namespace on port 8080 only. The second rule adds a
`podSelector` restriction and applies only to port 9090 — together this
gives each simulated "interface" its own independent reachability rule,
exactly the property a real Multus secondary NIC would also let you express
(just via a separate network attachment instead of a separate port).

## Verify

```bash
kubectl -n ckne-cni-06 exec client       -- wget -qT5 -O- http://data-svc.ckne-cni-06.svc.cluster.local:8080   # succeeds
kubectl -n ckne-cni-06 exec client       -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090   # times out
kubectl -n ckne-cni-06 exec admin-client -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090   # succeeds
make validate LAB=CNI-06
```
