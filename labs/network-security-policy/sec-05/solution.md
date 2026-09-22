# CKNE-SEC-05 — Solution

## Root cause

`backend` has no `NetworkPolicy`, so it accepts ingress from any Pod. Two Pods each satisfy exactly one of the two intended conditions: `worker-a` lives in the trusted `ckne-sec-05-clients` namespace but carries `role: worker`, and `rogue-frontend` carries `role: frontend` but lives in `backend`'s own, untrusted namespace. Only `frontend-a` satisfies both — an AND-combined rule is needed, not an OR of the two.

## Investigation process

```bash
kubectl -n ckne-sec-05 get networkpolicy
kubectl get namespace ckne-sec-05-clients --show-labels
kubectl -n ckne-sec-05-clients get pods --show-labels
kubectl -n ckne-sec-05 get pods --show-labels
```

No policy exists. `ckne-sec-05-clients` carries `team=payments`; `frontend-a` and `worker-a` live there with `role: frontend` and `role: worker` respectively; `rogue-frontend` sits in `backend`'s own namespace carrying `role: frontend`. `worker-a` is in the trusted namespace but has the wrong role, and `rogue-frontend` has the right-looking role but is in the wrong namespace — both must be blocked while `frontend-a` alone gets through.

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trusted-frontend
  namespace: ckne-sec-05
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              team: payments
          podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-05/manifests/expected/allow-trusted-frontend.yaml
```

The `namespaceSelector` and `podSelector` are both keys on the **same** `from` list element, so Kubernetes requires a source Pod to satisfy both at once. Writing them as two separate list elements instead would produce OR semantics and is the specific mistake this lab is designed to catch.

## Verification steps

```bash
kubectl -n ckne-sec-05-clients exec frontend-a    -- wget -qT5 -O- http://backend.ckne-sec-05.svc.cluster.local   # succeeds
kubectl -n ckne-sec-05-clients exec worker-a      -- wget -qT5 -O- http://backend.ckne-sec-05.svc.cluster.local   # times out
kubectl -n ckne-sec-05          exec rogue-frontend -- wget -qT5 -O- http://backend.ckne-sec-05.svc.cluster.local # times out
make validate LAB=SEC-05
```

## Why this works

A `NetworkPolicy` ingress rule's `from` field is a list, and each list element is evaluated independently — traffic is allowed if it matches *any* element (OR across the list). But within a single element, setting both `podSelector` and `namespaceSelector` requires both to match the same source Pod at once (AND within that element). Putting both selectors on one `from` entry means only Pods that are simultaneously in a `team: payments` namespace *and* carry `role: frontend` are allowed — `worker-a` fails the pod-label half, `rogue-frontend` fails the namespace half, and only `frontend-a` satisfies both. Splitting the same two selectors into two separate list elements would instead trust *any* Pod in the trusted namespace regardless of role, and *separately* trust any Pod anywhere carrying `role: frontend` regardless of namespace — a meaningfully more permissive (and wrong) posture.

## Faster exam-oriented method

Write the `from` entry with both selectors as sibling keys under one list dash from the start — this is a "know the YAML shape" task more than a diagnostic one. If unsure, mentally check: one `-` (one list element) with two keys = AND; two `-`s (two list elements) with one key each = OR.

## Common mistakes

- Writing `namespaceSelector` and `podSelector` as two separate `from` list elements instead of two keys on one element — silently switches AND to OR, letting `worker-a` and/or `rogue-frontend` through. This is precisely the bug `validate.sh` tests for by checking all three client Pods, not just `frontend-a`.
- Testing only `frontend-a` and declaring success — a policy with OR semantics would also let `frontend-a` through, so the bug is invisible unless `worker-a` and `rogue-frontend` are tested too.
- Modifying `role`/`team` labels on the client Pods or namespaces to make the test pass — violates the requirement to leave those labels untouched; the fix belongs entirely in the NetworkPolicy's selector structure.
- Assuming a `podSelector` alone (with no `namespaceSelector`) would work because it "defaults to the policy's own namespace" — that default does apply, but it's irrelevant here since `frontend-a` is not in `backend`'s own namespace; the trusted Pod lives in a different namespace entirely, which is exactly why `namespaceSelector` is required.

## Relevant documentation

- NetworkPolicy to/from selector behavior — https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors
- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource
- Labels and Selectors — https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
