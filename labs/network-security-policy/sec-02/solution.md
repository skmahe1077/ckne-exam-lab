# Solution — SEC-02

## Diagnosis

`default-deny-egress` selects `app: client` with `policyTypes: [Egress]` and
no `egress` rules — `client` cannot send ANY outbound traffic, including DNS
queries to CoreDNS, so name resolution itself fails before connectivity is
even attempted.

## Fix

Add a second NetworkPolicy with two egress rules (see
`manifests/expected/allow-dns-and-allowed-target.yaml`):

```bash
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-and-allowed-target
  namespace: ckne-sec-02
spec:
  podSelector:
    matchLabels:
      app: client
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
    - to:
        - podSelector:
            matchLabels:
              app: allowed-target
      ports:
        - protocol: TCP
          port: 80
YAML
```

## Verify

```bash
kubectl -n ckne-sec-02 exec client -- nslookup allowed-svc                              # resolves
kubectl -n ckne-sec-02 exec client -- wget -q -T 5 -O- http://allowed-svc               # succeeds
kubectl -n ckne-sec-02 exec client -- wget -q -T 5 -O- http://blocked-svc               # times out
make validate LAB=SEC-02
```
