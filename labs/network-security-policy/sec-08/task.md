# CKNE-SEC-08

**Task ID:** CKNE-SEC-08
**Domain:** Network Security and Policy
**Difficulty:** Advanced
**Estimated time:** 40 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-08
**Context:** default

## Scenario

A `backend` Deployment/Service in `ckne-sec-08` accepts any HTTP request on any path/method from any Pod right now — there is no `CiliumNetworkPolicy` yet. Two client Pods exist: `caller` (labeled `app: caller`, the only identity that should ever be allowed to talk to `backend`) and `outsider` (no special label, must never reach `backend` at all). Separately, this cluster's Cilium installation does not yet encrypt pod-to-pod traffic between nodes.

## Objective

Part A — L7 policy: restrict `backend` so that only `caller` may reach it, and even `caller` may only issue `GET /health` — every other request (including `POST /admin` from `caller` itself) must be rejected. Part B — transparent encryption: enable Cilium's WireGuard transparent encryption cluster-wide and confirm it is genuinely active.

## Requirements

**Part A — L7 CiliumNetworkPolicy (namespace-scoped, no lock):**

- Add a `CiliumNetworkPolicy` in `ckne-sec-08` selecting `backend` (`endpointSelector`), with an ingress rule whose `fromEndpoints` matches only Pods labeled `app: caller`.
- That rule's `toPorts` must restrict traffic to TCP/80 AND use an L7 `rules.http` entry allowing only `method: GET`, `path: /health`.
- Do not modify `backend`'s Deployment/Service or either client Pod's labels — the policy alone must produce the required behavior.
- `caller` issuing `GET /health` must succeed.
- `caller` issuing `POST /admin` (or any other method/path) must be rejected.
- `outsider` must be unable to reach `backend` on any path at all.

**Part B — Transparent Encryption (cluster-wide, lock required):**

- Acquire the shared lock on resource `cilium-config` before changing anything (`shared/scripts/lock.sh acquire cilium-config SEC-08` — this is done for you by `setup.sh`; you do not need to run it yourself unless you are re-running steps manually).
- Enable Cilium's WireGuard transparent encryption via Helm (`encryption.enabled=true`, `encryption.type=wireguard`) against the existing `cilium` release in `kube-system`.
- Confirm the Cilium DaemonSet remains healthy (Ready on every node) after the change.
- Confirm Cilium itself reports WireGuard encryption as active (both the Helm-driven ConfigMap value and the running agent's own status output) — do not just assume the `helm upgrade` succeeding is proof enough.
- Never modify a different Cilium Helm value than the ones listed above.

## Verification criteria

- Deployment `backend` is Ready.
- `caller` → `GET /health` on `backend`: succeeds.
- `caller` → `POST /admin` on `backend`: rejected.
- `outsider` → `backend` (any path): rejected.
- Cilium DaemonSet in `kube-system` is Ready on every node.
- `cilium-config` ConfigMap in `kube-system` reports WireGuard encryption enabled.
- A live Cilium agent's own status output reports WireGuard encryption active.

## Permitted references

- Cilium Network Policy — https://docs.cilium.io/en/stable/network/kubernetes/policy/
- Cilium L7 HTTP policy — https://docs.cilium.io/en/stable/security/policy/language/#http
- Cilium WireGuard transparent encryption — https://docs.cilium.io/en/stable/security/network/encryption-wireguard/
