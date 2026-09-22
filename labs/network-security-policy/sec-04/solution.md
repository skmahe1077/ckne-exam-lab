# Solution — SEC-04

## Diagnosis

`backend` has no NetworkPolicy, so it accepts ingress from any Pod in any
namespace, including `untrusted-client` in its own namespace. `client-a`
lives in `ckne-sec-04-clients`, which is already labeled
`network-access: trusted`.

## Fix

Apply a namespace-selector-only NetworkPolicy
(`manifests/expected/allow-trusted-namespace.yaml`):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trusted-namespace
  namespace: ckne-sec-04
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              network-access: trusted
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-04/manifests/expected/allow-trusted-namespace.yaml
```

## Verify

```bash
kubectl -n ckne-sec-04-clients exec client-a -- wget -qT5 -O- http://backend.ckne-sec-04.svc.cluster.local   # succeeds
kubectl -n ckne-sec-04 exec untrusted-client -- wget -qT5 -O- http://backend.ckne-sec-04.svc.cluster.local    # times out
make validate LAB=SEC-04
```

`untrusted-client` stays blocked because its namespace (`ckne-sec-04`) was
never labeled `network-access: trusted` — proximity to `backend` doesn't
matter to a namespace-selector rule.
