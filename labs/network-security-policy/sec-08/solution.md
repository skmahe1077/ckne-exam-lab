# Solution — SEC-08

## Part A — L7 CiliumNetworkPolicy

### Diagnosis

`backend` has no `CiliumNetworkPolicy`, so its catch-all nginx config
returns HTTP 200 for any path/method from any Pod, including `outsider`
and `caller`'s `POST /admin`.

### Fix

Apply `manifests/expected/backend-l7-http.yaml`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-l7-http
  namespace: ckne-sec-08
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: caller
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/health"
```

```bash
kubectl apply -f labs/network-security-policy/sec-08/manifests/expected/backend-l7-http.yaml
```

Once this `CiliumNetworkPolicy` selects `backend` for `Ingress`, `backend`
becomes default-deny: `outsider` (never matches `fromEndpoints`) is dropped
at L3/L4 before Envoy is even involved, and `caller` issuing anything other
than `GET /health` is dropped at L7 by Cilium's embedded Envoy proxy — a
plain `NetworkPolicy` has no mechanism to express the method/path part of
this at all.

### Verify

```bash
kubectl -n ckne-sec-08 exec caller   -- curl -s -o /dev/null -w '%{http_code}\n' -X GET  http://backend.ckne-sec-08.svc.cluster.local/health   # 200
kubectl -n ckne-sec-08 exec caller   -- curl -s -o /dev/null -w '%{http_code}\n' -X POST http://backend.ckne-sec-08.svc.cluster.local/admin    # 403 (or timeout)
kubectl -n ckne-sec-08 exec outsider -- curl -s -o /dev/null -w '%{http_code}\n' -X GET  http://backend.ckne-sec-08.svc.cluster.local/health   # timeout
```

## Part B — Transparent Encryption (WireGuard)

### Fix

`setup.sh` already acquired the `cilium-config` lock. Enable WireGuard:

```bash
helm upgrade cilium cilium/cilium --reuse-values \
  --set encryption.enabled=true --set encryption.type=wireguard \
  --namespace kube-system --wait --timeout 5m
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

### Verify

```bash
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}'; echo   # true
CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium-dbg status --brief | grep -i wireguard
make validate LAB=SEC-08
```

`cleanup.sh` reverts `encryption.enabled=false` via the same `--reuse-values`
pattern and then releases the `cilium-config` lock, so the next lab (or
`ATM-05`, which shares this same lock name by design since both labs touch
Cilium's Helm values) can safely acquire it.
