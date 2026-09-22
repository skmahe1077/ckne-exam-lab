# CKNE-SEC-10

**Task ID:** CKNE-SEC-10
**Domain:** Network Security and Policy
**Difficulty:** Advanced
**Estimated time:** 40 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-10
**Context:** default

## Scenario

`ckne-sec-10` is labeled `istio-injection: enabled`, and every Pod in it (including `backend`) has an `istio-proxy` sidecar. Right now `backend` has no `PeerAuthentication` or `AuthorizationPolicy` at all, so it accepts plaintext connections from anyone. Three caller Pods exist: `trusted-caller` (ServiceAccount `trusted-caller-sa` — the only identity that should ever reach `backend`), `untrusted-caller` (a different mesh identity, ServiceAccount `untrusted-caller-sa`, WITH a sidecar — a legitimate mesh member, just not one that should be allowed to call `backend`), and `no-mesh-caller` (explicitly opted OUT of sidecar injection via the `sidecar.istio.io/inject: "false"` annotation — a plaintext, non-mesh caller).

## Objective

Require mutual TLS for all traffic to workloads in `ckne-sec-10`, and restrict `backend` so only the `trusted-caller-sa` identity may call it.

## Requirements

- Add a `PeerAuthentication` in `ckne-sec-10` (no workload `selector`, so it covers the whole namespace) with `mtls.mode: STRICT`.
- Add an `AuthorizationPolicy` in `ckne-sec-10` selecting `backend` (`selector: {matchLabels: {app: backend}}`), `action: ALLOW`, with a single rule whose `from.source.principals` contains exactly `cluster.local/ns/ckne-sec-10/sa/trusted-caller-sa`.
- Do not create either object in `istio-system` or with no namespace scoping — both must stay scoped to `ckne-sec-10` only.
- Do not modify `backend`, any caller Pod, or any ServiceAccount.
- `trusted-caller` must still be able to reach `backend`.
- `untrusted-caller` (has a sidecar, wrong identity) must be rejected.
- `no-mesh-caller` (no sidecar, plaintext) must be rejected.

## Verification criteria

- `PeerAuthentication` exists in `ckne-sec-10` with `spec.mtls.mode == STRICT`.
- `AuthorizationPolicy` exists in `ckne-sec-10`, selecting `app: backend`, allowing only the `trusted-caller-sa` principal.
- A request from `trusted-caller` to `backend` succeeds.
- A request from `untrusted-caller` to `backend` fails (rejected by AuthorizationPolicy).
- A request from `no-mesh-caller` to `backend` fails (rejected by STRICT mTLS — no sidecar means no client certificate to present).

## Permitted references

- Istio PeerAuthentication — https://istio.io/latest/docs/reference/config/security/peer_authentication/
- Istio AuthorizationPolicy — https://istio.io/latest/docs/reference/config/security/authorization-policy/
- Istio mutual TLS — https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication
