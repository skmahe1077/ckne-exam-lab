# CKNE-ATM-06

**Task ID:** CKNE-ATM-06
**Domain:** Advanced Traffic Management
**Difficulty:** Advanced
**Estimated time:** 35 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-atm-06
**Context:** default

## Scenario

**Scope limitation:** this environment has only one real Kubernetes cluster. This task is a configuration and control-plane readiness exercise for Cilium Cluster Mesh — it does NOT connect a second cluster and does NOT test actual cross-cluster traffic or failover. You are exercising exactly the parts of Cluster Mesh that are testable with one cluster: the control-plane component and the per-Service opt-in configuration. See `concept.md` for the full reasoning.

Cilium Cluster Mesh's control-plane component, `clustermesh-apiserver`, has already been deployed into `kube-system` (a precondition of this lab, not something you need to change) along with its generated mTLS certificates. A `catalog` Deployment and Service are running in `ckne-atm-06`, serving traffic normally within this cluster — but the Service has not been configured as a Cluster Mesh global service, so if a second cluster were ever connected to this one, `catalog` would never be discovered from it.

## Objective

Confirm the `clustermesh-apiserver` control plane is healthy, then configure the `catalog` Service so it is correctly marked for cross-cluster discovery.

## Requirements

- Do not modify the `catalog` Deployment — it is already correct.
- Do not modify `clustermesh-apiserver` or its Secrets — they are a precondition, already correctly deployed.
- Add the annotation that marks `catalog` as a Cluster Mesh global service, so that in a real multi-cluster mesh it would be discovered and load-balanced to from any connected remote cluster.
- Do not change the Service's selector, ports, or type — only its annotations need to change.

## Verification criteria

- The Cilium DaemonSet in kube-system is Ready on every node (precondition, not something you are asked to change).
- `clustermesh-apiserver` in kube-system has a Ready Deployment and an existing Service (precondition, not something you are asked to change).
- The four `clustermesh-apiserver-*-cert` Secrets in kube-system each contain non-empty `tls.crt`, `tls.key`, and `ca.crt` data (precondition, not something you are asked to change).
- Deployment `catalog` in `ckne-atm-06` is Ready.
- Service `catalog` carries the annotation `service.cilium.io/global: "true"`.

## Permitted references

- Cilium Cluster Mesh — https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/
- Cilium Cluster Mesh services — https://docs.cilium.io/en/stable/network/clustermesh/services/
