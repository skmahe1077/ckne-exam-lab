# CKNE-SEC-04 — Solution

## Root cause

`backend` has no `NetworkPolicy`, so it accepts ingress from any Pod in any namespace — including `untrusted-client`, which lives in `backend`'s own namespace (`ckne-sec-04`) but whose namespace is not labeled `network-access: trusted`.

## Investigation process

```bash
kubectl -n ckne-sec-04 get networkpolicy
kubectl get namespace ckne-sec-04-clients --show-labels
```

No policy exists, and `ckne-sec-04-clients` (home of `client-a`) already carries `network-access=trusted`. Compare it against `backend`'s own namespace:

```bash
kubectl get namespace ckne-sec-04 --show-labels
kubectl get namespace ckne-sec-04-clients --show-labels
```

`ckne-sec-04` (where `untrusted-client` lives) does not carry `network-access=trusted` — the namespace's own label is what matters, not physical/logical proximity to `backend`.

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trusted-namespace
  namespace: ckne-sec-04
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
              network-access: trusted
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-04/manifests/expected/allow-trusted-namespace.yaml
```

## Verification steps

```bash
kubectl -n ckne-sec-04-clients exec client-a -- wget -qT5 -O- http://backend.ckne-sec-04.svc.cluster.local   # succeeds
kubectl -n ckne-sec-04 exec untrusted-client -- wget -qT5 -O- http://backend.ckne-sec-04.svc.cluster.local    # times out
make validate LAB=SEC-04
```

`untrusted-client` stays blocked because its namespace was never labeled `network-access: trusted` — proximity to `backend` doesn't matter to a namespace-selector rule.

## Why this works

A `NetworkPolicy` ingress rule's `from.namespaceSelector` matches traffic based on the **namespace's own labels**, not what labels the originating Pod itself carries — the decision is made on *where a Pod lives*, not *what a Pod is labeled*. `ckne-sec-04-clients` carries `network-access: trusted`, so every Pod inside it (including `client-a`) is allowed, uniformly, without needing an individual Pod label. `ckne-sec-04` itself — `backend`'s own namespace — does not carry that label, so `untrusted-client` is blocked exactly like a Pod three namespaces away would be. This is the key distinction from a `podSelector` rule (SEC-03): here, a Pod being "local" to `backend` grants it no special trust at all.

## Faster exam-oriented method

`kubectl get namespace ckne-sec-04 ckne-sec-04-clients --show-labels` side by side — spot which namespace carries `network-access=trusted` and which doesn't. Write the namespace-selector-only ingress rule directly; no need to separately inspect Pod labels since this policy intentionally ignores them.

## Common mistakes

- Adding a `podSelector` alongside the `namespaceSelector` in the same `from` entry — the requirements explicitly call for a pure namespace-selector rule; combining them narrows the match to Pods with *both* the namespace label and a specific Pod label, which isn't what's being tested.
- Assuming `untrusted-client` should be allowed because it's "in the same namespace as `backend`" — namespace-selector policy cares only about the label on the *source* Pod's namespace, and proximity to the backend is irrelevant.
- Labeling `ckne-sec-04` (or any other namespace) as `network-access: trusted` to make the test pass — violates the requirement not to create/label any namespace beyond what's already there; the fix belongs entirely in the NetworkPolicy, not in namespace labels.
- Forgetting the label lives on the `Namespace` object, not the Pods inside it — `kubectl label namespace <ns> ...` is a separate operation from labeling individual Pods, and this lab's policy depends on the former.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource
- NetworkPolicy to/from selector behavior — https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors
- Labels and Selectors — https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
