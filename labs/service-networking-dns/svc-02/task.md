# CKNE-SVC-02

**Task ID:** CKNE-SVC-02
**Domain:** Service Networking and DNS
**Difficulty:** Beginner
**Estimated time:** 15 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-02
**Context:** default

## Scenario

A `web` Deployment (2 replicas, nginx) and a `web` NodePort Service were deployed into the `ckne-svc-02` namespace. `kubectl get svc` shows the Service has a `nodePort` assigned in the 30000-32767 range, and `kubectl get endpoints` shows Pod IPs — but requests through the Service still fail.

This cluster's security group only allows inbound traffic on the NodePort range (30000-32767) from within the cluster's own network, not from the internet. That is expected and is not the bug you're looking for — test from inside the cluster.

## Objective

Find why traffic through the NodePort Service isn't reaching the `web` Pods, and fix it.

## Requirements

- Confirm the `web` Deployment is 2/2 Ready and the Service has healthy Endpoints (both already true — the problem is elsewhere).
- Confirm the Service's `type` is `NodePort` and it has a `nodePort` allocated in the 30000-32767 range (already true).
- Inspect the Service's `targetPort` against the port the `web` container actually listens on.
- Fix the Service (minimum change necessary) so traffic sent to a node's IP on the allocated nodePort actually reaches a Pod.

## Verification criteria

- Service `web` in `ckne-svc-02` has `spec.type == NodePort` with `spec.ports[0].nodePort` inside 30000-32767.
- Service `web`'s Endpoints list 2 healthy Pod IPs.
- A request sent to `<any-node-IP>:<nodePort>` from inside the cluster succeeds end-to-end and returns a response from nginx.

## Permitted references

- Kubernetes Services (NodePort) — https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport
