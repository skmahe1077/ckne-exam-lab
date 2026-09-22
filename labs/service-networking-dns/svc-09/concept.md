# Concept: GatewayClass, Gateway, and HTTPRoute

The Kubernetes Gateway API splits "expose an HTTP service to traffic" into
three separate objects, each owned by a different persona:

- **`GatewayClass`** (cluster-scoped) — declares that a particular
  controller (here, Cilium's, `controllerName: io.cilium/gateway-controller`)
  is available to implement Gateways. This is infrastructure-team-owned and
  installed once, cluster-wide — exactly like a `StorageClass` or
  `IngressClass`. Application teams reference it by name; they never create
  or edit it themselves.
- **`Gateway`** (namespaced) — a concrete listener configuration: which
  port(s), which protocol(s) (HTTP, HTTPS, TCP, ...), and which namespaces'
  `HTTPRoute`s are allowed to attach to it. Creating a `Gateway` with
  `gatewayClassName: cilium` tells Cilium's controller "provision me a data
  plane for this". Cilium's implementation responds by provisioning an
  Envoy-based data plane and a `Service` (named
  `cilium-gateway-<gateway-name>`) fronting it — this is how you actually
  reach the Gateway from inside the cluster (or, with a LoadBalancer, from
  outside).
- **`HTTPRoute`** (namespaced) — the actual routing rules: which
  hostnames/paths/headers match, and which backend `Service` each match
  routes to. An `HTTPRoute` attaches to one or more `Gateway`s via
  `parentRefs`, and is otherwise independent — the same `Gateway` can have
  many `HTTPRoute`s attached (from the same or, if the `Gateway`'s
  `allowedRoutes` permits it, other namespaces), each owned by a different
  team.

This split matters operationally: a platform team can lock down exactly who
is allowed to expose what (via `GatewayClass` + `Gateway` ownership) while
application teams retain full self-service control over their own routing
rules (`HTTPRoute`), without either team needing access to the other's
objects. `status.conditions` on both `Gateway` (`Accepted`, `Programmed`)
and `HTTPRoute` (`Accepted`, `ResolvedRefs`) tell you, object by object,
exactly where a broken chain is — a `Gateway` that's `Programmed=True` but
an `HTTPRoute` that never got attached is a very different problem than a
`Gateway` stuck `Programmed=False`.
