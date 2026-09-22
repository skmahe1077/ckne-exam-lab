# Solution — SVC-09

## Diagnosis

```bash
kubectl get gatewayclass cilium
# Accepted: True

kubectl -n ckne-svc-09 get gateway,httproute
# No resources found
```

`web` is healthy but has no `Gateway`/`HTTPRoute` pointing at it — nothing
is broken, there's simply nothing built yet.

## Fix

Create the `Gateway` (see `manifests/expected/gateway.yaml`):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: svc09-gw
  namespace: ckne-svc-09
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
```

Create the `HTTPRoute` (see `manifests/expected/httproute.yaml`):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: ckne-svc-09
spec:
  parentRefs:
    - name: svc09-gw
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web
          port: 80
```

```bash
kubectl apply -f manifests/expected/gateway.yaml
kubectl apply -f manifests/expected/httproute.yaml
```

## Verify

```bash
kubectl -n ckne-svc-09 get gateway svc09-gw
# PROGRAMMED: True

kubectl -n ckne-svc-09 get svc cilium-gateway-svc09-gw
GW_IP=$(kubectl -n ckne-svc-09 get svc cilium-gateway-svc09-gw -o jsonpath='{.spec.clusterIP}')

kubectl -n ckne-svc-09 run check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- "http://${GW_IP}/"
# svc09-backend

make validate LAB=SVC-09
```
