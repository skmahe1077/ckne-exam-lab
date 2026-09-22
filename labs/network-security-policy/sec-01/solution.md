# Solution — SEC-01

## Diagnosis

`default-deny-ingress` selects every Pod (`podSelector: {}`) with
`policyTypes: [Ingress]` and no `ingress` rules — so no Pod in the namespace
can receive any ingress traffic, including `client-frontend` talking to
`backend`.

## Fix

Add a second NetworkPolicy scoping an allow rule to exactly the intended
client (see `manifests/expected/allow-frontend-to-backend.yaml`):

```bash
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: ckne-sec-01
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
YAML
```

Because NetworkPolicies are additive, `default-deny-ingress` and
`allow-frontend-to-backend` both select `backend`'s Pods; the union of their
Ingress rules is exactly "allow from `role: frontend`, deny everything
else."

## Verify

```bash
kubectl -n ckne-sec-01 exec client-frontend -- wget -q -T 5 -O- http://backend   # succeeds
kubectl -n ckne-sec-01 exec client-other    -- wget -q -T 5 -O- http://backend   # times out
make validate LAB=SEC-01
```
