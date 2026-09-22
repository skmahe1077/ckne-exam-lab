# Concept: Namespace-Selector NetworkPolicy

A `NetworkPolicy` ingress rule's `from` list can match traffic by
**namespace** instead of (or in addition to) by Pod label:

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            network-access: trusted
```

This says: allow traffic from any Pod running in a namespace whose own
**namespace-level labels** match `network-access: trusted` — regardless of
what labels that Pod itself carries. This is the key mental model shift
from pod-selector policies (SEC-03): the decision is made based on *where a
Pod lives*, not *what a Pod is labeled*.

Two things trip people up:

- **Proximity is irrelevant.** A Pod in `backend`'s own namespace is not
  automatically trusted just because it's "local" — if that namespace
  itself isn't labeled `network-access: trusted`, a namespace-selector rule
  blocks it exactly like it would block a Pod three namespaces away.
- **The label lives on the `Namespace` object, not the Pod.**
  `kubectl label namespace <ns> network-access=trusted` — a completely
  separate operation from labeling the Pods inside it, and one that affects
  every Pod in that namespace uniformly (even future ones).

Cilium implements standard `NetworkPolicy` on top of its own eBPF datapath
identically in behavior to any other CNI that supports the NetworkPolicy
API — no Cilium-specific syntax is needed for this.
