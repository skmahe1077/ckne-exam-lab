# Solution — SVC-10

## Diagnosis

```bash
kubectl -n ckne-svc-10 get httproute web-route -o yaml
```

`status.parents[0].conditions` shows `ResolvedRefs: False`, reason
`RefNotPermitted` — the HTTPRoute's `backendRef` is correctly written
(right Service name, right namespace, right port), but nothing in
`ckne-svc-10-backend` has consented to being referenced from
`ckne-svc-10`.

```bash
kubectl -n ckne-svc-10-backend get referencegrant
# No resources found
```

## Fix

Create a `ReferenceGrant` **in `ckne-svc-10-backend`** (see
`manifests/expected/referencegrant.yaml`):

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-svc10-httproutes
  namespace: ckne-svc-10-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: ckne-svc-10
  to:
    - group: ""
      kind: Service
      name: backend
```

```bash
kubectl apply -f manifests/expected/referencegrant.yaml
```

## Verify

```bash
kubectl -n ckne-svc-10 get httproute web-route -o jsonpath='{.status.parents[0].conditions}'
# ResolvedRefs: True

GW_IP=$(kubectl -n ckne-svc-10 get svc cilium-gateway-svc10-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-svc-10 run check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- "http://${GW_IP}/"
# svc10-backend

make validate LAB=SVC-10
```

Nothing about the `Gateway`, `HTTPRoute`, or `backend` was ever wrong —
the exercise is precisely that cross-namespace references in Gateway API
are opt-in from the *target* namespace's side, so the fix for a rejected
reference is almost never in the object doing the referencing.
