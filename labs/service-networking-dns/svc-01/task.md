# CKNE-SVC-01

**Task ID:** CKNE-SVC-01
**Domain:** Service Networking and DNS
**Difficulty:** Beginner
**Estimated time:** 15 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-01
**Context:** default

## Scenario

An `api` Deployment (2 replicas, nginx) and an `api` ClusterIP Service were deployed into the `ckne-svc-01` namespace. The Deployment's Pods are 2/2 Ready, but nothing reaches them through the Service — every request times out.

## Objective

Determine why the Service isn't routing traffic to the `api` Deployment's Pods, and fix it so the Service actually delivers requests to them.

## Requirements

- Confirm the `api` Deployment is 2/2 Ready (it already is — the problem is not the Pods).
- Inspect the Service's Endpoints/EndpointSlices to see whether it has picked up any Pod backends at all.
- Compare the Service's `spec.selector` against the actual labels on the Deployment's Pods.
- Fix the Service (minimum change necessary) so it selects the `api` Pods correctly.
- Do not change the Deployment's Pod labels — fix the Service.

## Verification criteria

- Deployment `api` in `ckne-svc-01` has `status.readyReplicas == 2` (unchanged precondition).
- Service `api`'s Endpoints/EndpointSlices list exactly 2 Pod IPs.
- A request to the `api` Service's ClusterIP on port 80 succeeds end-to-end from inside the cluster (not just "Service exists" or "Endpoints non-empty").

## Permitted references

- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
- Kubernetes EndpointSlices — https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
