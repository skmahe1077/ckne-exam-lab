# CKNE-ATM-01

**Task ID:** CKNE-ATM-01
**Domain:** Advanced Traffic Management
**Difficulty:** Beginner
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-atm-01
**Context:** default

## Scenario

Two independent backends, `blue` and `green`, are running in the `ckne-atm-01` namespace, each behind its own Service, fronted by a single Gateway (`atm-gw`, using the cluster's shared `cilium` GatewayClass). Two HTTPRoute objects were written to route traffic to them — one by hostname, one by path — but someone swapped things around: requests for `blue.ckne.local` currently reach the `green` backend (and vice versa), and requests to `/blue` currently reach `green` (and vice versa).

## Objective

Fix the HTTPRoute objects `host-routes`, `host-routes-green`, and `path-routes` in `ckne-atm-01` so that host-based and path-based routing both send traffic to the correct backend.

## Requirements

- A request with `Host: blue.ckne.local` must be routed to the `blue` backend.
- A request with `Host: green.ckne.local` must be routed to the `green` backend.
- A request to `Host: app.ckne.local`, path `/blue`, must be routed to the `blue` backend.
- A request to `Host: app.ckne.local`, path `/green`, must be routed to the `green` backend.
- Do not modify the Gateway, the backend Deployments/Services, or the GatewayClass — only the HTTPRoute objects need to change.

## Verification criteria

- The shared GatewayClass `cilium` is Accepted (precondition, not something you are asked to change).
- Gateway `atm-gw` in `ckne-atm-01` reports condition `Programmed=True`.
- A real HTTP request with `Host: blue.ckne.local` against the Gateway returns a body containing `blue-backend`.
- A real HTTP request with `Host: green.ckne.local` against the Gateway returns a body containing `green-backend`.
- A real HTTP request with `Host: app.ckne.local` and path `/blue` returns a body containing `blue-backend`.
- A real HTTP request with `Host: app.ckne.local` and path `/green` returns a body containing `green-backend`.

## Permitted references

- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/api-types/httproute/
- Gateway API concepts — https://kubernetes.io/docs/concepts/services-networking/gateway/
- Service concept — https://kubernetes.io/docs/concepts/services-networking/service/
