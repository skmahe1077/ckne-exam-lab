# CKNE-SEC-07

**Task ID:** CKNE-SEC-07
**Domain:** Network Security and Policy
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-07
**Context:** default

## Scenario

A `client` Deployment runs in `ckne-sec-07`. A `deny-all-egress` NetworkPolicy already denies ALL outbound traffic from every Pod in the namespace — including DNS. Right now `client` cannot resolve any name at all, not even `kubernetes.default.svc.cluster.local`.

## Objective

Without removing or weakening `deny-all-egress`, add exactly the egress needed for DNS to work: allow `client` to reach CoreDNS (`kube-dns`) in `kube-system` on UDP and TCP port 53. Every other form of outbound traffic (including to an arbitrary external IP) must remain blocked.

## Requirements

- Do not edit or delete the existing `deny-all-egress` NetworkPolicy.
- Create a second, additive `NetworkPolicy` in `ckne-sec-07` that allows egress from `client` to Pods matching `k8s-app: kube-dns` in the `kube-system` namespace, restricted to UDP port 53 and TCP port 53 only — no other destinations or ports.
- `kubernetes.io/metadata.name: kube-system` is the standard immutable label Kubernetes auto-applies to every namespace; use it in your `namespaceSelector` rather than a label you would have to add yourself.
- After your fix, DNS resolution from `client` must succeed, and a raw TCP connection attempt from `client` to an arbitrary external destination on a non-DNS port must still fail.

## Verification criteria

- Deployment `client` in `ckne-sec-07` is Ready.
- `client` can resolve `kubernetes.default.svc.cluster.local` via DNS.
- `client` cannot open a TCP connection to an external IP on a non-DNS port (e.g. 1.1.1.1:443).

## Permitted references

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Well-known namespace labels — https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/#automatic-labelling
