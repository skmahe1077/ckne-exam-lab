# CKNE-ATM-05

**Task ID:** CKNE-ATM-05
**Domain:** Advanced Traffic Management
**Difficulty:** Intermediate
**Estimated time:** 30 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-atm-05
**Context:** default

## Scenario

Cilium's egress gateway feature has already been enabled cluster-wide (a precondition of this lab, not something you need to change), and one worker node has already been labeled `ckne.openai.com/atm-05-egress-node=true` as this lab's designated egress gateway. A cluster-scoped `CiliumEgressGatewayPolicy` named `ckne-atm-05-egress-policy` was created to route all traffic from the `egress-client` Deployment's Pods, destined for `1.1.1.1/32`, through that gateway node. The policy applied cleanly with no errors — but traffic from `egress-client` is not actually being redirected through the gateway node at all.

## Objective

Diagnose why the `CiliumEgressGatewayPolicy` isn't redirecting `egress-client`'s traffic, and fix it with the minimum change necessary so that it does.

## Requirements

- Do not change `destinationCIDRs`, the `egressGateway.nodeSelector`, or the `namespaceSelector` — they are already correct.
- Do not relabel any node and do not change the egress-client Deployment's Pod labels.
- Fix the `CiliumEgressGatewayPolicy`'s `podSelector` so it actually selects the `egress-client` Deployment's Pods.
- Confirm the fix using a live Cilium agent's own view of the datapath (the CRD itself has no status field to check).

## Verification criteria

- The Cilium DaemonSet in kube-system is Ready on every node (precondition, not something you are asked to change).
- `cilium-config` in kube-system reports the egress gateway feature enabled (precondition, not something you are asked to change).
- Deployment `egress-client` in `ckne-atm-05` is Ready.
- `cilium-dbg bpf egress list`, run against a live Cilium agent, shows `egress-client`'s Pod IP mapped to destination `1.1.1.1/32` through the designated gateway node — proving the datapath, not just the API object, actually redirects the traffic.

## Permitted references

- Cilium Egress Gateway — https://docs.cilium.io/en/stable/network/egress-gateway/
- Cilium CLI reference (cilium-dbg) — https://docs.cilium.io/en/stable/cmdref/cilium-dbg/
