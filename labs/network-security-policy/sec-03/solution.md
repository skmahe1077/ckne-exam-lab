# Solution — SEC-03

## Diagnosis

No NetworkPolicy exists in `ckne-sec-03`, so Kubernetes' default (allow all
ingress) still applies — both `client-frontend` and `client-other` can reach
`backend`.

## Fix

Create a NetworkPolicy that selects `backend` and allows ingress only from
Pods labeled `role: frontend` (see
`manifests/expected/allow-frontend-pod-selector.yaml`):

```bash
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-pod-selector
  namespace: ckne-sec-03
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

This single policy implicitly denies every Pod not matching `role: frontend`
(because it's the first Ingress-typed policy to select `backend`) while
explicitly allowing the one label that should be able to connect.

## Verify

```bash
kubectl -n ckne-sec-03 exec client-frontend -- wget -q -T 5 -O- http://backend   # succeeds
kubectl -n ckne-sec-03 exec client-other    -- wget -q -T 5 -O- http://backend   # times out
make validate LAB=SEC-03
```
