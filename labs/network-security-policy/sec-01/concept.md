# Concept: Default-Deny Ingress with a Scoped Allow Rule

By default, Kubernetes networking is flat: any Pod can send traffic to any
other Pod, in any namespace, on any port. A `NetworkPolicy` is how you
restrict that — but only for Pods it *selects*. The moment ANY NetworkPolicy
with `policyTypes: [Ingress]` selects a Pod, that Pod's ingress behaviour
flips from "allow everything" to "deny everything except what an Ingress
rule explicitly allows." A `NetworkPolicy` with an empty `podSelector: {}`
and no `ingress` rules is the idiomatic "deny all ingress in this
namespace" — it selects every Pod, sets `policyTypes: [Ingress]`, and
provides zero allow rules, so nothing gets through.

NetworkPolicies are **additive** (whitelist), not first-match/override:
multiple NetworkPolicies can select the same Pod, and the effective allowed
traffic is the UNION of every matching Ingress rule across all of them. This
is why the fix here is to ADD a second, narrowly-scoped policy rather than
edit or delete the default-deny policy — the default-deny policy contributes
no allow rules, and your new policy contributes exactly one: "from Pods
labeled `role: frontend`, to Pods labeled `app: backend`, on TCP/80."

A Pod-selector-scoped `from` entry matches Pods by label *within the same
namespace as the NetworkPolicy* (no `namespaceSelector` means "this
namespace only"). This is the narrowest, least-privilege way to express
"only this specific kind of client may talk to this backend."
