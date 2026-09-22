# Concept: Combined Pod and Namespace Selectors (AND vs. OR)

A `NetworkPolicy` ingress rule's `from` field is a **list**. Each element of
that list is independently evaluated, and traffic is allowed if it matches
**any** element (logical OR across the list). But *within* a single list
element, if you set both `podSelector` and `namespaceSelector`, both must
match the same source Pod (logical AND within that one element):

```yaml
# AND: source Pod must be in a namespace matching the namespaceSelector
# AND carry labels matching the podSelector — both conditions on the SAME
# element.
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            team: payments
        podSelector:
          matchLabels:
            role: frontend
```

```yaml
# OR: source Pod matches if EITHER the namespace matches OR the Pod's own
# labels match — two SEPARATE elements in the from list.
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            team: payments
      - podSelector:
          matchLabels:
            role: frontend
```

These look almost identical — the only difference is indentation/YAML
structure (one list item with two keys, versus two list items with one key
each) — but they produce very different security postures:

- The **AND** form only trusts frontend Pods that live *inside* the trusted
  namespace.
- The **OR** form (a common mistake) trusts **any** Pod inside the trusted
  namespace regardless of its own labels, **and separately** trusts any Pod
  anywhere in the cluster carrying `role: frontend` — including Pods in
  namespaces that were never meant to be trusted at all. This is
  meaningfully more permissive than intended, and is exactly the kind of
  subtle policy bug that a security review (or the CKNE exam) expects you to
  be able to spot and explain.

When `podSelector` has no `namespaceSelector` alongside it in the same list
element, it implicitly scopes to the **policy's own namespace only** — that
default is a separate, related detail worth knowing but not what this lab
tests (this lab always pairs the `podSelector` with an explicit
`namespaceSelector` in the same element).
