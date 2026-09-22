# CKNE-SVC-09 — Solution

## Root cause

No bug to find — `web` is healthy but has no `Gateway`/`HTTPRoute` pointing at it at all. The exercise is to author both objects from scratch, referencing the shared `GatewayClass` `cilium` by name only.

## Investigation process

```bash
kubectl get gatewayclass cilium
# Accepted: True

kubectl -n ckne-svc-09 get gateway,httproute
# No resources found

kubectl -n ckne-svc-09 get deployment,svc web
```

The shared `GatewayClass` is `Accepted` and `web` is Ready — nothing is broken, there's simply nothing built yet.

## Corrected configuration

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
---
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
kubectl apply -f labs/service-networking-dns/svc-09/manifests/expected/gateway.yaml
kubectl apply -f labs/service-networking-dns/svc-09/manifests/expected/httproute.yaml
```

## Verification steps

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

## Why this works

The Gateway API splits "expose an HTTP service" into three objects owned by different personas. `GatewayClass` (cluster-scoped) declares that Cilium's controller is available to implement Gateways — infrastructure-owned, installed once, referenced by name only, never created or edited by an application team. `Gateway` (namespaced) is a concrete listener configuration; creating one with `gatewayClassName: cilium` tells Cilium's controller to provision a real data plane, which responds by creating an Envoy-based backend and a Service (`cilium-gateway-<gateway-name>`) that's the actual reachable entry point. `HTTPRoute` (namespaced) is the routing rules — it attaches to a `Gateway` via `parentRefs` and decides which backend Service each match routes to. This split lets a platform team own who's allowed to expose what while application teams retain full self-service control over their own routing, without either needing access to the other's objects. Once both objects exist and the Gateway reports `Programmed=True`, requests to its auto-created Service are handled per the `HTTPRoute`'s rules, landing on `web`.

## Faster exam-oriented method

Two small manifests applied together: a `Gateway` referencing `gatewayClassName: cilium` with one HTTP listener on port 80 (`allowedRoutes.namespaces.from: Same`), and an `HTTPRoute` with `parentRefs` naming that Gateway and a single catch-all `/` rule to `web:80`. Confirm with `kubectl get gateway -o jsonpath='{.status.conditions}'` and one curl against the auto-created `cilium-gateway-*` Service.

## Common mistakes

- Creating or editing a `GatewayClass` instead of referencing the existing shared one by name — explicitly disallowed; `cilium` is a cluster-wide resource used by every other lab.
- Sending the verification request to `web`'s own ClusterIP instead of the Gateway's auto-created `cilium-gateway-<name>` Service — the task specifically requires proving traffic flows *through the Gateway*, not just that the backend Service itself works (which was never in question).
- Omitting `allowedRoutes` on the Gateway's listener — without it, the default `From: Same` behavior may or may not apply depending on the implementation; the task explicitly asks for it to be set so same-namespace `HTTPRoute`s are allowed to attach.
- Forgetting `parentRefs` on the `HTTPRoute`, or misnaming the Gateway it references — an `HTTPRoute` with no valid `parentRefs` match never attaches, and the Gateway stays `Programmed=True` while serving nothing.

## Relevant documentation

- Gateway API concepts — https://kubernetes.io/docs/concepts/services-networking/gateway/
- Gateway API Gateway resource — https://gateway-api.sigs.k8s.io/reference/api-types/gateway/
- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/reference/api-types/httproute/
- Gateway API GatewayClass — https://gateway-api.sigs.k8s.io/reference/api-types/gatewayclass/
- Cilium Gateway API — https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
