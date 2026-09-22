# Concept: Host- and Path-Based Routing with the Gateway API

The Kubernetes Gateway API splits "who owns the load balancer" from "who
owns the routing rules." A **GatewayClass** (cluster-scoped, here the
shared `cilium` class backed by `io.cilium/gateway-controller`) names an
implementation. A **Gateway** (namespaced) is a concrete instance of that
class — it opens one or more **listeners** (protocol + port, optionally a
hostname) and is usually owned by a platform/infra team. An **HTTPRoute**
(namespaced) attaches to a Gateway via `parentRefs` and defines the actual
L7 routing rules — normally owned by an application team, which is the
point of the split: app teams don't need access to edit the shared Gateway
to change their own routing.

Cilium implements Gateway API using its Envoy-based datapath. When a
Gateway is created, Cilium provisions a Kubernetes Service named
`cilium-gateway-<gateway-name>` in the Gateway's namespace — that Service's
ClusterIP (or, on a cloud with a load-balancer controller, an external IP)
is the actual entry point traffic arrives at.

An `HTTPRoute`'s `spec.hostnames` field filters which `Host` header the
*entire* route applies to (intersected with any hostname restriction on the
Gateway listener it attaches to) — this is why host-based routing to two
different backends needs two separate HTTPRoute objects here, one per
hostname. Within a single HTTPRoute, `spec.rules[].matches[].path` narrows
routing further by URL path, letting one hostname fan out to multiple
backends by path prefix. Rule precedence in the Gateway API spec favors
more specific matches (exact path over prefix, longer prefix over shorter),
which is what lets `/blue` and `/green` coexist safely as sibling rules
under the same hostname.
