# CKNE-SVC-10

**Task ID:** CKNE-SVC-10
**Domain:** Service Networking and DNS
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-10 (plus a second namespace this lab owns: ckne-svc-10-backend)
**Context:** default

## Scenario

A `Gateway` (`svc10-gw`) and an `HTTPRoute` (`web-route`) already exist in `ckne-svc-10`. The `HTTPRoute` is already written correctly, with a `backendRef` that explicitly crosses into a second namespace, `ckne-svc-10-backend`, where a healthy `backend` Deployment/Service is running. But the Gateway API spec requires a `ReferenceGrant` to exist in the target namespace before a cross-namespace `backendRef` like this one is honored — and no `ReferenceGrant` exists yet, so the reference is rejected and requests through the Gateway fail.

## Objective

Create the `ReferenceGrant` that permits `ckne-svc-10`'s `HTTPRoute` to reference the `backend` Service in `ckne-svc-10-backend`, and prove the cross-namespace route works end-to-end.

## Requirements

- Do not modify the `Gateway`, the `HTTPRoute`, or the `backend` Deployment/Service — they are already correct. The only object you need to create is a `ReferenceGrant`.
- Create the `ReferenceGrant` in `ckne-svc-10-backend` (the namespace being referenced INTO — not `ckne-svc-10`, where the `HTTPRoute` lives).
- The `ReferenceGrant` must permit `HTTPRoute` resources (`group: gateway.networking.k8s.io`) from `ckne-svc-10` to reference `Service` resources (`group: ""`) in `ckne-svc-10-backend`.
- Confirm `web-route`'s status now reports `ResolvedRefs=True`.
- Confirm a real HTTP request through the Gateway reaches the `backend` Service in the other namespace.

## Verification criteria

- The shared `GatewayClass` `cilium` is `Accepted` (precondition, not something you are asked to change).
- Deployment `backend` in `ckne-svc-10-backend` remains `1/1` Ready.
- `Gateway` `svc10-gw` in `ckne-svc-10` remains `Programmed=True`.
- `HTTPRoute` `web-route` in `ckne-svc-10` reports `ResolvedRefs=True`.
- At least one `ReferenceGrant` exists in `ckne-svc-10-backend`.
- A real HTTP request sent to the Gateway's auto-created ClusterIP Service (`cilium-gateway-svc10-gw`) on port 80 returns a body containing `svc10-backend`.

## Permitted references

- Gateway API ReferenceGrant — https://gateway-api.sigs.k8s.io/api-types/referencegrant/
- Gateway API cross-namespace routing — https://gateway-api.sigs.k8s.io/guides/multiple-ns/
