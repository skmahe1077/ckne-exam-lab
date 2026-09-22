# CKNE-CNI-06

**Task ID:** CKNE-CNI-06
**Domain:** Core Infrastructure and CNI
**Difficulty:** Advanced
**Estimated time:** 35 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-cni-06
**Context:** default

## Scenario

This cluster does not have Multus installed, so genuine secondary-NIC "multi-interface Pod" attachment is not available. A `multi-iface-app` Pod has already been deployed to simulate the pattern instead: it runs two containers in the same Pod, `data-plane` (HTTP on port 8080) and `mgmt-plane` (HTTP on port 9090), standing in for what would otherwise be two separately-attached NICs. Two Services, `data-svc` and `mgmt-svc`, each front one of those ports. Two client Pods already exist: `client` (an ordinary workload, no special label) and `admin-client` (labeled `role: admin`). Right now there is no `NetworkPolicy` at all, so both client Pods can reach both `data-svc` and `mgmt-svc` — the management plane is not actually restricted to admins.

## Objective

First, confirm directly that this Pod has only one real network interface (one `podIP`) despite exposing two logical "interfaces" via its two containers/ports — do not assume this, check it. Then add a `NetworkPolicy` that enforces per-interface ingress rules: the data plane (port 8080) must stay reachable from any Pod in the namespace, but the management plane (port 9090) must become reachable only from Pods labeled `role: admin`.

## Requirements

- Inspect `multi-iface-app`'s Pod spec/status and confirm it has exactly one entry in `status.podIPs` (a single real interface) even though it serves two logical interfaces via its two containers.
- Add a `NetworkPolicy` in `ckne-cni-06` selecting `multi-iface-app`'s Pods, with `Ingress` in `policyTypes`.
- Port 8080 (`data-plane`) must remain reachable from any Pod in `ckne-cni-06` (do not restrict it by `podSelector`).
- Port 9090 (`mgmt-plane`) must be reachable only from Pods carrying the label `role: admin`.
- Do not add a second container, a second Pod IP, or any Multus-related object — this task is solved entirely with a `NetworkPolicy`.
- Do not modify the `client` or `admin-client` Pods or their labels.

## Verification criteria

- Deployment `multi-iface-app` is Ready (both containers Ready).
- The Pod has exactly one `podIP`.
- `client` (no special label) can reach `data-svc:8080` successfully.
- `client` cannot reach `mgmt-svc:9090` (blocked).
- `admin-client` (`role: admin`) can reach `mgmt-svc:9090` successfully.
- `admin-client` can also reach `data-svc:8080` successfully.

## Permitted references

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Pod status podIPs — https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodStatus
