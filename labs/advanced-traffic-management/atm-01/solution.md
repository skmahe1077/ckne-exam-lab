# CKNE-ATM-01 — Solution

## Root cause

All three `HTTPRoute` objects have their `backendRefs` swapped relative to what they match: `host-routes` (hostname `blue.ckne.local`) points at the `green` Service, `host-routes-green` (hostname `green.ckne.local`) points at `blue`, and within `path-routes`, the `/blue` rule points at `green` while the `/green` rule points at `blue`.

## Investigation process

```bash
kubectl -n ckne-atm-01 get gateway atm-gw
kubectl -n ckne-atm-01 get httproute
kubectl -n ckne-atm-01 get svc
```

Confirm the Gateway, and the `blue`/`green` Services and Deployments, are healthy first — they are not the problem.

```bash
kubectl -n ckne-atm-01 get httproute host-routes -o yaml
kubectl -n ckne-atm-01 get httproute host-routes-green -o yaml
kubectl -n ckne-atm-01 get httproute path-routes -o yaml
```

- `host-routes` has `hostnames: [blue.ckne.local]` but `rules[0].backendRefs[0].name: green`.
- `host-routes-green` has `hostnames: [green.ckne.local]` but `rules[0].backendRefs[0].name: blue`.
- `path-routes` has a `/blue` rule pointing at `backendRefs.name: green`, and a `/green` rule pointing at `backendRefs.name: blue`.

## Corrected configuration

```yaml
# host-routes
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: host-routes
  namespace: ckne-atm-01
spec:
  parentRefs:
    - name: atm-gw
  hostnames:
    - blue.ckne.local
  rules:
    - backendRefs:
        - name: blue
          port: 80
---
# host-routes-green
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: host-routes-green
  namespace: ckne-atm-01
spec:
  parentRefs:
    - name: atm-gw
  hostnames:
    - green.ckne.local
  rules:
    - backendRefs:
        - name: green
          port: 80
---
# path-routes
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: path-routes
  namespace: ckne-atm-01
spec:
  parentRefs:
    - name: atm-gw
  hostnames:
    - app.ckne.local
  rules:
    - matches:
        - path: { type: PathPrefix, value: /blue }
      backendRefs:
        - name: blue
          port: 80
    - matches:
        - path: { type: PathPrefix, value: /green }
      backendRefs:
        - name: green
          port: 80
```

Equivalent inline patches (no full rewrite needed):

```bash
kubectl -n ckne-atm-01 patch httproute host-routes --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"blue"}]'

kubectl -n ckne-atm-01 patch httproute host-routes-green --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"green"}]'

kubectl -n ckne-atm-01 patch httproute path-routes --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"blue"},
       {"op":"replace","path":"/spec/rules/1/backendRefs/0/name","value":"green"}]'
```

## Verification steps

```bash
GW_IP=$(kubectl -n ckne-atm-01 get svc cilium-gateway-atm-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-atm-01 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: blue.ckne.local" "http://$GW_IP/"
kubectl -n ckne-atm-01 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: green.ckne.local" "http://$GW_IP/"
kubectl -n ckne-atm-01 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: app.ckne.local" "http://$GW_IP/blue"
kubectl -n ckne-atm-01 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: app.ckne.local" "http://$GW_IP/green"
make validate LAB=ATM-01
```

## Why this works

An `HTTPRoute`'s `spec.hostnames` filters which `Host` header the entire route applies to, which is why host-based routing to two different backends needs two separate `HTTPRoute` objects here (`host-routes` and `host-routes-green`) rather than one. Within a single `HTTPRoute`, `spec.rules[].matches[].path` narrows routing further by URL path, letting one hostname (`app.ckne.local`) fan out to multiple backends by path prefix. In both cases, each rule's `backendRefs` is independent of every other rule's — matching correctly and forwarding correctly are two separate pieces of configuration, and this lab's break was purely in the second piece. Lining up each rule's `backendRefs.name` with what it matches restores the intended mapping without touching the Gateway, GatewayClass, or backend Services/Deployments at all.

## Faster exam-oriented method

`kubectl get httproute -n ckne-atm-01 -o yaml` for all three routes at once, and scan each `rules[].backendRefs[].name` against the hostname/path just above it — for routes this small, the swap is visible immediately without needing to curl first. Fix with the three `kubectl patch` commands above (or `kubectl edit`) and curl once afterward to confirm.

## Common mistakes

- Editing the `blue`/`green` Services' selectors instead of the routes — masks the symptom by making the wrong Service point at the wrong Pods, which breaks the requirement not to modify the backend Deployments/Services.
- Editing the Gateway's listeners to try to fix routing — the Gateway and GatewayClass are correct preconditions; the break is entirely inside the three `HTTPRoute` objects.
- Fixing only `host-routes` and `host-routes-green` and forgetting `path-routes` also has its `backendRefs` swapped (or vice versa) — all three objects are independently broken.
- Curling the `blue`/`green` Services directly instead of the Gateway's `cilium-gateway-atm-gw` Service — that bypasses the routing layer entirely and will pass even if the routes are still broken.

## Relevant documentation

- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/api-types/httproute/
- Gateway API concepts — https://kubernetes.io/docs/concepts/services-networking/gateway/
- Service concept — https://kubernetes.io/docs/concepts/services-networking/service/
