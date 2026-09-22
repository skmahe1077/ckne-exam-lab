# CKNE-ATM-03

**Task ID:** CKNE-ATM-03
**Domain:** Advanced Traffic Management
**Difficulty:** Intermediate
**Estimated time:** 25 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-atm-03
**Context:** default

## Scenario

A `stable` backend and a `canary` backend are running in the `ckne-atm-03` namespace, each behind its own Service, fronted by a single Gateway (`atm-gw`, using the cluster's shared `cilium` GatewayClass). The HTTPRoute `canary-split` currently splits traffic evenly (50/50) between them via `backendRefs[].weight`. The team wants to dial the canary back to a conservative 20% of traffic before a wider rollout.

## Objective

Change the `backendRefs` weights on HTTPRoute `canary-split` in `ckne-atm-03` so that approximately 80% of traffic reaches `stable` and approximately 20% reaches `canary`.

## Requirements

- `backendRefs[].weight` for `stable` and `canary` must together express an 80/20 ratio (e.g. `80`/`20`, or any equivalent 4:1 ratio such as `8`/`2` or `40`/`10` — Gateway API weighting is proportional, not an absolute percentage).
- Do not modify the Gateway, the backend Deployments/Services, or the GatewayClass — only the HTTPRoute's weights need to change.
- Do not remove either backendRef — both `stable` and `canary` must remain reachable.

## Verification criteria

- The shared GatewayClass `cilium` is Accepted (precondition, not something you are asked to change).
- Gateway `atm-gw` in `ckne-atm-03` reports condition `Programmed=True`.
- `validate.sh` sends 40 real HTTP requests through the Gateway and classifies each response by which backend answered.
- IMPORTANT — statistical tolerance: because 40 requests over a proportional load balancer is a small, inherently noisy sample, validate.sh does **not** require an exact 80/20 split. It passes if the observed stable share is within the band [55%, 100%] and the observed canary share is within the band [0%, 45%] — i.e. +/-25 percentage points around the 80/20 target. This is intentionally generous; it is there to catch "you didn't change the weights at all" or "you flipped the ratio," not to demand statistical precision.

## Permitted references

- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/api-types/httproute/
- Gateway API HTTPBackendRef reference — https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPBackendRef
- Gateway API concepts — https://kubernetes.io/docs/concepts/services-networking/gateway/
