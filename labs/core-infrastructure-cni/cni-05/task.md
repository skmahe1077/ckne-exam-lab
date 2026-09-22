# CKNE-CNI-05

**Task ID:** CKNE-CNI-05
**Domain:** Core Infrastructure and CNI
**Difficulty:** Intermediate
**Estimated time:** 25 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-cni-05
**Context:** default

## Scenario

A `server` Deployment (nginx) and its Service are running normally in `ckne-cni-05`. A Pod named `client` is Running, but every DNS lookup from inside it — including for `server`'s own Service name — fails or times out.

## Objective

Determine whether this is a cluster-wide DNS problem (CoreDNS itself broken) or something specific to the `client` Pod, then fix the real cause so `client` can resolve and reach `server` again.

## Requirements

- Check CoreDNS's health cluster-wide (kube-system) as your first step — rule a cluster-wide outage in or out before touching anything in your namespace.
- Inspect how `client` is actually configured to do DNS resolution — this is a Pod-level setting, not something CoreDNS controls (`kubectl -n ckne-cni-05 get pod client -o yaml`, look at `dnsPolicy` and `dnsConfig`).
- Compare that against how `server`'s Pod resolves DNS by default, to see what's different.
- Fix `client`'s DNS configuration with the minimum change necessary so it uses normal in-cluster DNS resolution again. Do not modify CoreDNS or anything in `kube-system` — it is a shared, cluster-level resource used by every other lab.
- Confirm `client` can resolve `server`'s Service name and successfully connect to it.

## Verification criteria

- The CoreDNS Deployment in kube-system is Ready (this must remain true — validate.sh checks it as a precondition, not as something you are asked to change).
- Deployment `server` is 1/1 Ready.
- Pod `client` is Running.
- `client` successfully resolves `server.ckne-cni-05.svc.cluster.local` via DNS.
- `client` successfully connects to `server` over HTTP using that name.

## Permitted references

- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Pod DNS policy — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy
- CoreDNS — https://coredns.io/manual/toc/
