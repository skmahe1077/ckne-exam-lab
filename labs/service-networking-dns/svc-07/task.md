# CKNE-SVC-07

**Task ID:** CKNE-SVC-07
**Domain:** Service Networking and DNS
**Difficulty:** Intermediate
**Estimated time:** 25 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-07
**Context:** default

## Scenario

This cluster runs kube-proxy in `iptables` mode (see `kubectl -n kube-system get pods -l k8s-app=kube-proxy` and `kubectl -n kube-system get configmap kube-proxy -o yaml`). A `web` Deployment (2 replicas, nginx) already exists in `ckne-svc-07`, but it has no Service yet.

## Objective

Create a ClusterIP Service exposing the `web` Deployment, then prove — by directly inspecting the node's iptables rules, not just by assuming — that kube-proxy actually programmed a path from the Service's ClusterIP to the backing Pods' IPs.

## Requirements

- Create a Service named `web` in `ckne-svc-07` that selects the existing `web` Pods and exposes port 80.
- kube-proxy's iptables rules live in the node's root network namespace, not inside an ordinary Pod's own network namespace — a normal Pod's `iptables-save` will show nothing about Services. To see the real rules, run a debug Pod with `hostNetwork: true` and the `NET_ADMIN`/`NET_RAW` capabilities added, then run `iptables-save` inside it.
- In that output, find the rule(s) that reference your Service's ClusterIP (`kubectl -n ckne-svc-07 get service web -o jsonpath='{.spec.clusterIP}'`) and identify the chain kube-proxy created for it (`KUBE-SVC-...`) and the per-Pod chains it jumps to (`KUBE-SEP-...`).
- Confirm the Service actually delivers traffic to the Pods end-to-end (a Service can exist and still be misconfigured — selector mismatch, wrong port — such that no working iptables path gets programmed).

## Verification criteria

- Service `web` exists in `ckne-svc-07`, is type `ClusterIP`, selects the `web` Pods, and exposes port 80.
- The Service's Endpoints/EndpointSlice list both `web` Pod IPs.
- The node's iptables rules (inspected via a `hostNetwork` + `NET_ADMIN`/`NET_RAW` debug Pod) contain a rule referencing the Service's ClusterIP.
- A request to the Service's ClusterIP on port 80 succeeds end-to-end.

## Permitted references

- kube-proxy iptables mode — https://kubernetes.io/docs/reference/networking/virtual-ips/#proxy-mode-iptables
- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
