# CKNE-SEC-04

**Task ID:** CKNE-SEC-04
**Domain:** Network Security and Policy
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-04 (plus a second namespace this lab owns: ckne-sec-04-clients)
**Context:** default

## Scenario

A `backend` Deployment/Service in `ckne-sec-04` currently has no NetworkPolicy at all, so any Pod from any namespace can reach it — including `untrusted-client`, which lives right there in `ckne-sec-04` itself. A second namespace, `ckne-sec-04-clients`, is labeled `network-access: trusted` and contains `client-a`, which is supposed to be allowed to reach `backend`.

## Objective

Restrict ingress to `backend` so that only Pods running in namespaces labeled `network-access: trusted` can reach it — regardless of any label on the Pod itself, and regardless of which namespace the Pod is physically "close to".

## Requirements

- Add a NetworkPolicy in `ckne-sec-04` that allows ingress to `backend` (TCP port 80) only from Pods in namespaces matching `namespaceSelector: {matchLabels: {network-access: trusted}}`.
- Do not add a `podSelector` on the `from` side — this must be a pure namespace-selector rule.
- Do not modify the `network-access: trusted` label on `ckne-sec-04-clients`, or create/label any other namespace.
- `client-a` (in `ckne-sec-04-clients`) must be able to reach `backend`.
- `untrusted-client` (in `ckne-sec-04` itself, an untrusted namespace) must remain blocked.

## Verification criteria

- Deployment `backend` is Ready.
- `ckne-sec-04-clients` still carries `network-access=trusted`.
- A request from `client-a` to `backend` succeeds within 5 seconds.
- A request from `untrusted-client` to `backend` fails/times out.

## Permitted references

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy namespaceSelector reference — https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
