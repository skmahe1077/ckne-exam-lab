# CKNE-SEC-05

**Task ID:** CKNE-SEC-05
**Domain:** Network Security and Policy
**Difficulty:** Intermediate
**Estimated time:** 25 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-05 (plus a second namespace this lab owns: ckne-sec-05-clients)
**Context:** default

## Scenario

A `backend` Deployment/Service in `ckne-sec-05` currently has no `NetworkPolicy` at all. `ckne-sec-05-clients` is labeled `team: payments` and contains two Pods: `frontend-a` (labeled `role: frontend`) and `worker-a` (labeled `role: worker` — same trusted namespace, different role). `ckne-sec-05` itself (backend's own, untrusted namespace) also contains `rogue-frontend`, a Pod that carries `role: frontend` even though it does not live in the trusted namespace.

## Objective

Restrict ingress to `backend` so that only Pods which are **both** (a) in a namespace labeled `team: payments` **and** (b) carrying the Pod label `role: frontend` can reach it. Neither condition alone is sufficient.

## Requirements

- Add a `NetworkPolicy` in `ckne-sec-05` that allows ingress to `backend` (TCP port 80) only from Pods matching BOTH `namespaceSelector: {matchLabels: {team: payments}}` AND `podSelector: {matchLabels: {role: frontend}}` combined as a single AND condition (one `from` list element carrying both selectors) — not as two separate `from` list elements (which would mean OR, not AND).
- Do not modify the `team: payments` label on `ckne-sec-05-clients`, the `role` labels on `frontend-a`/`worker-a`/`rogue-frontend`, or create/label any other namespace.
- `frontend-a` (trusted namespace + correct role) must be able to reach `backend`.
- `worker-a` (trusted namespace, wrong role) must remain blocked.
- `rogue-frontend` (correct role, untrusted namespace) must remain blocked.

## Verification criteria

- Deployment `backend` is Ready.
- `ckne-sec-05-clients` still carries `team=payments`.
- A request from `frontend-a` to `backend` succeeds within 5 seconds.
- A request from `worker-a` to `backend` fails/times out.
- A request from `rogue-frontend` to `backend` fails/times out.

## Permitted references

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy combined selectors — https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors
