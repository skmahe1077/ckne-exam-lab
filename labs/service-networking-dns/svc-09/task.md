# CKNE-SVC-09

**Task ID:** CKNE-SVC-09
**Domain:** Service Networking and DNS
**Difficulty:** Advanced
**Estimated time:** 30 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-09
**Context:** default

## Scenario

A `web` Deployment and ClusterIP Service are running in `ckne-svc-09`, serving distinct, identifiable content. The cluster already has a shared, cluster-wide Gateway API `GatewayClass` named `cilium` (`controllerName: io.cilium/gateway-controller`), installed once by `kubeadm-setup/install-addons.sh` — but no `Gateway` or `HTTPRoute` exists yet in `ckne-svc-09`, so `web` is unreachable from outside its own ClusterIP.

## Objective

Author a `Gateway` and an `HTTPRoute` in `ckne-svc-09` from scratch that together expose `web` over HTTP, referencing the shared `GatewayClass` by name only.

## Requirements

- Do not create, edit, or delete the `GatewayClass` named `cilium` — it is a shared, cluster-wide resource used by every other lab. Reference it by name only: `gatewayClassName: cilium`.
- Do not modify the `web` Deployment, Service, or ConfigMap.
- Create a `Gateway` in `ckne-svc-09` with a single HTTP listener on port 80, restricted to `HTTPRoute`s in the same namespace (`allowedRoutes.namespaces.from: Same`).
- Create an `HTTPRoute` that attaches to your `Gateway` (via `parentRefs`) and routes requests to the `web` Service on port 80.
- Confirm your `Gateway` reports `status.conditions[type=Programmed] == True`.
- Confirm a real HTTP request through the Gateway (not the Service directly) reaches `web` and returns its content.

## Verification criteria

- The shared `GatewayClass` `cilium` is `Accepted` (precondition, not something you are asked to change).
- Deployment `web` in `ckne-svc-09` remains `1/1` Ready.
- A `Gateway` using `gatewayClassName: cilium` exists in `ckne-svc-09` and reports `Programmed=True`.
- A real HTTP request sent to the Gateway's auto-created ClusterIP Service (`cilium-gateway-<your-gateway-name>`) on port 80 returns a body containing `svc09-backend`.

## Permitted references

- Gateway API concepts — https://kubernetes.io/docs/concepts/services-networking/gateway/
- Gateway API Gateway resource — https://gateway-api.sigs.k8s.io/api-types/gateway/
- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/api-types/httproute/
