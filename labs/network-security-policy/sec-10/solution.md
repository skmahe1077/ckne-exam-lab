# Solution — SEC-10

## Diagnosis

`backend` has no `PeerAuthentication` and no `AuthorizationPolicy`, so
despite having a sidecar, it currently accepts plaintext connections from
`no-mesh-caller` and mTLS connections from any mesh identity, including
`untrusted-caller`.

## Fix

Apply both reference objects:

```yaml
# manifests/expected/peer-authentication.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: ckne-sec-10-strict-mtls
  namespace: ckne-sec-10
spec:
  mtls:
    mode: STRICT
```

```yaml
# manifests/expected/authorization-policy.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: backend-allow-trusted-caller
  namespace: ckne-sec-10
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/ckne-sec-10/sa/trusted-caller-sa"
```

```bash
kubectl apply -f labs/network-security-policy/sec-10/manifests/expected/peer-authentication.yaml
kubectl apply -f labs/network-security-policy/sec-10/manifests/expected/authorization-policy.yaml
```

`PeerAuthentication` in `STRICT` mode makes `backend`'s sidecar reject any
inbound connection that isn't mTLS — that alone is enough to block
`no-mesh-caller` (no sidecar, so no client certificate to present).
`AuthorizationPolicy` then narrows WHO among already-mTLS-authenticated
callers may connect: because it selects `backend` and lists only
`trusted-caller-sa`, any other identity — including the legitimate mesh
member `untrusted-caller-sa` — is denied with an HTTP 403 from the
sidecar's RBAC filter.

## Verify

```bash
kubectl -n ckne-sec-10 exec trusted-caller   -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local   # 200
kubectl -n ckne-sec-10 exec untrusted-caller -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local   # 403
kubectl -n ckne-sec-10 exec no-mesh-caller   -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local   # 000 / connection failure
make validate LAB=SEC-10
```
