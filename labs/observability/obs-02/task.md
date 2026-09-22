# CKNE-OBS-02

**Task ID:** CKNE-OBS-02
**Domain:** Observability
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-obs-02
**Context:** default

## Scenario

An `orders` Deployment (2 replicas, nginx) and its ClusterIP Service were deployed into the `ckne-obs-02` namespace. Every request to the `orders` Service fails. Someone on the team suspects CoreDNS is broken.

## Objective

Use CoreDNS's own logs to rule DNS in or out, then correctly diagnose the actual Service/Endpoint health problem and fix it.

## Requirements

- Read the CoreDNS Pods' logs in `kube-system` (`kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100`) and look for any errors related to the `orders` Service or the `ckne-obs-02` namespace.
- Independently confirm whether DNS resolution of `orders.ckne-obs-02.svc.cluster.local` actually succeeds from inside the cluster (it does — a Service's DNS record exists as soon as the Service object exists, regardless of whether it has healthy backends).
- Having ruled out DNS, inspect the Service's Endpoints (`kubectl -n ckne-obs-02 get endpoints orders`) — are there any?
- Diagnose why the `orders` Pods are not contributing Endpoints (`kubectl -n ckne-obs-02 describe pod -l app=orders`, `kubectl -n ckne-obs-02 get pods`) — Running is not the same as Ready.
- Fix the actual root cause with the minimum change necessary. Do not modify CoreDNS — it was never the problem.
- The `orders` Service must route traffic to both Pods.

## Verification criteria

- CoreDNS Deployment in `kube-system` is Ready (this must remain true — validate.sh checks it as a precondition, not as something you are asked to change).
- Deployment `orders` in `ckne-obs-02` has `status.readyReplicas == 2`.
- Service `orders`'s Endpoints list exactly 2 Pod IPs.
- DNS resolution of `orders.ckne-obs-02.svc.cluster.local` succeeds from inside the cluster.
- A request to the `orders` Service's ClusterIP on port 80 succeeds end-to-end.

## Permitted references

- CoreDNS — https://coredns.io/manual/toc/
- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Kubernetes EndpointSlices — https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
