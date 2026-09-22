# CKNE-SEC-03 — Solution

## Root cause

No `NetworkPolicy` exists in `ckne-sec-03`, so Kubernetes' default (allow all ingress) still applies — both `client-frontend` and `client-other` can reach `backend`, when only `role: frontend` Pods should be able to.

## Investigation process

```bash
kubectl -n ckne-sec-03 get networkpolicy
kubectl -n ckne-sec-03 exec client-other -- wget -q -T 5 -O- http://backend
```

No policy exists, and `client-other` (which should be blocked) currently succeeds. Confirm the label each client Pod actually carries:

```bash
kubectl -n ckne-sec-03 get pods --show-labels
```

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-pod-selector
  namespace: ckne-sec-03
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-03/manifests/expected/allow-frontend-pod-selector.yaml
```

## Verification steps

```bash
kubectl -n ckne-sec-03 exec client-frontend -- wget -q -T 5 -O- http://backend   # succeeds
kubectl -n ckne-sec-03 exec client-other    -- wget -q -T 5 -O- http://backend   # times out
make validate LAB=SEC-03
```

## Why this works

The moment any `NetworkPolicy` with `policyTypes: [Ingress]` selects a Pod, Kubernetes implicitly switches that Pod from "allow all ingress" to "deny all ingress except what's explicitly listed." Because no policy previously selected `backend`, writing this single policy does two things at once: it implicitly denies every Pod that doesn't match the `from` rule, and it explicitly allows exactly the one label (`role: frontend`) specified. A `podSelector` with no accompanying `namespaceSelector` implicitly means "Pods matching this label, in the same namespace as the policy" — the narrowest way to express "only clients carrying this label may talk to this backend" without hardcoding IPs that change every time a Pod is rescheduled. This differs from a default-deny-plus-separate-allow setup (see SEC-01): here, one object produces both the implicit deny and the explicit allow.

## Faster exam-oriented method

`kubectl get networkpolicy -n ckne-sec-03` returning empty means "start from scratch" — write the single pod-selector-scoped policy directly (`podSelector: {app: backend}`, one ingress rule `from: podSelector {role: frontend}`, `port: 80/TCP`) without needing to separately reason about a deny baseline.

## Common mistakes

- Using an `ipBlock` or `namespaceSelector` in the `from` clause instead of a `podSelector` — the requirements explicitly call for a `podSelector` match on `role: frontend`; an IP-based rule would also be fragile since Pod IPs change on reschedule.
- Forgetting that creating this one policy is sufficient — no separate "default-deny" object is needed here, since any Ingress-typed policy selecting a Pod implicitly denies everything not explicitly allowed.
- Omitting `ports` from the ingress rule — without it, `role: frontend` Pods would be allowed on every port, wider than the TCP/80-only requirement.
- Selecting the wrong label in `podSelector.matchLabels` (e.g. matching `app: client` instead of `role: frontend`) — the two client Pods are distinguished by their `role` label, not `app`, so the wrong key/value lets both or neither client through.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy API reference — https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
