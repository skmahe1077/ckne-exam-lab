# CKNE-SEC-03

**Task ID:** CKNE-SEC-03
**Domain:** Network Security and Policy
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-03
**Context:** default

## Scenario

A `backend` Deployment (nginx) and Service, plus two client Pods — `client-frontend` (labeled `role: frontend`) and `client-other` (labeled `role: other`) — run in `ckne-sec-03`. There is currently NO NetworkPolicy in the namespace at all, so `backend` accepts ingress from every Pod, including `client-other`, which should never be allowed to reach it.

## Objective

Write a NetworkPolicy, from scratch, that restricts ingress to `backend` so that only Pods carrying the label `role: frontend` can reach it.

## Requirements

- Create a NetworkPolicy selecting `app: backend` Pods for `Ingress`.
- The `from` clause must use a `podSelector` matching `role: frontend` — do not use an IP block or a namespaceSelector for this rule.
- Scope the rule to TCP port 80.
- `client-frontend` must be able to reach `backend`; `client-other` must not.

## Verification criteria

- At least one NetworkPolicy exists in `ckne-sec-03`.
- A request from `client-frontend` to the `backend` Service succeeds within a 5-second timeout.
- A request from `client-other` to the `backend` Service fails/times out.

## Permitted references

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy podSelector reference — https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
