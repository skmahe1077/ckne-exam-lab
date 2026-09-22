# Concept: Headless Services and StatefulSet DNS

A regular ClusterIP Service gives you one stable virtual IP that
load-balances across all matching Pods — perfect when you don't care which
specific backend Pod answers a request. A **StatefulSet** is built for the
opposite case: each Pod has a stable identity (`web-0`, `web-1`, `web-2`,
...) and other components sometimes need to talk to *one specific* replica
(a database primary vs. replicas, a cluster member needing to gossip with
a named peer, etc.). A shared VIP can't express that — you can't ask a
ClusterIP "give me Pod 0 specifically."

Setting `clusterIP: None` on a Service turns it **headless**: Kubernetes
no longer allocates any ClusterIP at all. Instead, CoreDNS's `kubernetes`
plugin changes what it returns for that Service's DNS name entirely — for
a headless Service, a lookup of `<svc>.<namespace>.svc.cluster.local`
returns the *set* of all backing Pod IPs directly (no VIP indirection),
and, critically for StatefulSets, CoreDNS also publishes one record **per
Pod**: `<pod-name>.<svc>.<namespace>.svc.cluster.local` resolving to that
individual Pod's own IP. The StatefulSet controller is what gives each Pod
its predictable `<statefulset-name>-<ordinal>` hostname in the first
place; the headless governing Service (referenced via the StatefulSet's
`spec.serviceName`) is what turns those hostnames into real, resolvable
per-Pod DNS records.

If the governing Service is left as a normal (non-headless) ClusterIP
Service, the StatefulSet's Pods still get created fine and the Service
still load-balances traffic across them — but the per-Pod DNS records
never get created, silently breaking any component that relies on
addressing a specific replica by name. This is a subtle failure mode
because nothing about the StatefulSet or its Pods looks unhealthy; only a
DNS lookup for an individual Pod's name reveals the problem.

One operational wrinkle: `spec.clusterIP` is immutable after a Service is
created. You cannot `kubectl patch` your way from a real ClusterIP to
`None` — the Service object must be deleted and recreated.
