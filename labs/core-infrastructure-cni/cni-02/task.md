# CKNE-CNI-02

**Task ID:** CKNE-CNI-02
**Domain:** Core Infrastructure and CNI
**Difficulty:** Beginner
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-cni-02
**Context:** default

## Scenario

A `server` Deployment (nginx) and a `client` Deployment (busybox) are both running and Ready in `ckne-cni-02`. A `NetworkPolicy` named `allow-server-ingress` is supposed to let `client` reach `server` on port 80, but requests from `client` time out.

## Objective

Determine why traffic is blocked and fix it by correcting the NetworkPolicy so it actually matches the IP range Pods in this cluster are allocated from, then confirm `client` can reach `server` end-to-end.

## Requirements

- Determine the cluster's actual Pod CIDR by inspecting real, running Pod IPs (`kubectl get pods -o wide` in this namespace, or any other namespace) — do not assume a value, confirm it.
- Inspect the `allow-server-ingress` NetworkPolicy and compare its `ipBlock.cidr` against the real Pod IP range you just confirmed.
- Fix the NetworkPolicy with the minimum change necessary. Do not delete the NetworkPolicy and do not widen it to `0.0.0.0/0` — it must still scope ingress to the cluster's actual Pod CIDR, not open it to everything.
- Confirm `client` can now reach `server` on port 80.

## Verification criteria

- Deployments `server` and `client` are both 1/1 Ready.
- Every Pod in the namespace has a PodIP inside 10.244.0.0/16.
- The NetworkPolicy `allow-server-ingress` still exists (the fix is a correction, not a removal).
- A request from the `client` Pod to the `server` Pod's IP on port 80 succeeds.

## Permitted references

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy IPBlock reference — https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
