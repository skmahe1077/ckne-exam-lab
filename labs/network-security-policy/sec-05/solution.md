# Solution — SEC-05

## Diagnosis

`backend` has no `NetworkPolicy`, so it currently accepts ingress from any
Pod. Two Pods each satisfy exactly one of the two intended conditions:
`worker-a` lives in the trusted `ckne-sec-05-clients` namespace but carries
`role: worker`, and `rogue-frontend` carries `role: frontend` but lives in
`backend`'s own, untrusted namespace. Only `frontend-a` satisfies both.

## Fix

Apply an AND-combined NetworkPolicy
(`manifests/expected/allow-trusted-frontend.yaml`):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trusted-frontend
  namespace: ckne-sec-05
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
              team: payments
          podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-05/manifests/expected/allow-trusted-frontend.yaml
```

The `namespaceSelector` and `podSelector` are both keys on the **same**
`from` list element, so Kubernetes requires a source Pod to satisfy both at
once. Writing them as two separate list elements instead —

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            team: payments
      - podSelector:
          matchLabels:
            role: frontend
```

— would incorrectly let `worker-a` through (namespace alone matches the
first element) and would also incorrectly let `rogue-frontend` through
(pod label alone matches the second element). `validate.sh` specifically
tests both of those Pods to catch this mistake.

## Verify

```bash
kubectl -n ckne-sec-05-clients exec frontend-a    -- wget -qT5 -O- http://backend.ckne-sec-05.svc.cluster.local   # succeeds
kubectl -n ckne-sec-05-clients exec worker-a      -- wget -qT5 -O- http://backend.ckne-sec-05.svc.cluster.local   # times out
kubectl -n ckne-sec-05          exec rogue-frontend -- wget -qT5 -O- http://backend.ckne-sec-05.svc.cluster.local # times out
make validate LAB=SEC-05
```
