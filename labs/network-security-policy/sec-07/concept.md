# Concept: DNS Egress Under a Default-Deny Policy

A `NetworkPolicy` with `podSelector: {}`, `policyTypes: [Egress]`, and an
empty `egress: []` list denies ALL egress from every Pod it selects — that
includes DNS lookups, because DNS is just another UDP/TCP flow from the Pod
to CoreDNS's Pod IP on port 53. This is a very common real-world mistake:
teams apply a default-deny-egress policy for security, and every application
in the namespace immediately starts failing with DNS timeouts, because
nothing explicitly re-allowed traffic to CoreDNS.

`NetworkPolicy` objects for the same Pods are **additive** — Kubernetes does
not merge or override them, it evaluates each Pod's applicable ingress and
egress rules by taking the union of every policy that selects it. That means
you almost never edit a broad default-deny policy directly to add
exceptions; instead you add a second, narrower policy alongside it. This
keeps the "deny everything" baseline auditable and unmodified while making
each specific carve-out its own reviewable object.

The DNS carve-out itself needs both a `namespaceSelector` (to reach into
`kube-system`, a different namespace than the Pod being restricted) and a
`podSelector` (to target only the `kube-dns` Pods within it, not everything
in `kube-system`) combined inside the same `to` peer — and both UDP and TCP
port 53, since DNS resolvers fall back to TCP for responses too large for a
single UDP datagram (and some resolvers, or CoreDNS itself under load, use
TCP more proactively).

This pattern generalizes: any default-deny-egress namespace needs an
explicit DNS-allow rule before anything else can be expected to work,
independent of whatever other application-specific egress rules you add
afterward.
