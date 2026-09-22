# Solution — SEC-07

## Diagnosis

`deny-all-egress` (`podSelector: {}`, `policyTypes: [Egress]`, empty
`egress: []`) blocks all outbound traffic from `client`, including DNS
lookups to CoreDNS. It must stay in place — the fix is an additive policy,
not an edit.

## Fix

Apply `manifests/expected/networkpolicy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: ckne-sec-07
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

```bash
kubectl apply -f labs/network-security-policy/sec-07/manifests/expected/networkpolicy.yaml
```

## Verify

```bash
kubectl -n ckne-sec-07 exec deploy/client -- nslookup kubernetes.default.svc.cluster.local   # succeeds
kubectl -n ckne-sec-07 exec deploy/client -- sh -c 'timeout 3 nc -zv 1.1.1.1 443'             # fails/times out
make validate LAB=SEC-07
```

Only DNS traffic to `kube-dns` is carved out — every other destination
stays blocked by `deny-all-egress`.
