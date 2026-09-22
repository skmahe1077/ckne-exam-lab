# Concept: Cilium Cluster Mesh — Cross-Cluster Load-Balancing Affinity

Once a Service is marked `service.cilium.io/global: "true"` (see ATM-06),
Cilium load-balances requests to it across the union of that Service's
backends in every connected cluster by default — a client in cluster A can
just as easily land on a Pod in cluster B as one in cluster A. That's often
exactly what you want for stateless, latency-insensitive workloads, but it's
frequently the *wrong* default: cross-cluster hops usually cross an
inter-region or inter-AZ network link, adding real latency and egress cost
that a same-cluster hop never pays.

The `service.cilium.io/affinity` annotation lets you express a preference
without giving up the cross-cluster fallback entirely. It takes three
values:

- `none` (default) — no preference; Cilium load-balances across all healthy
  backends, local and remote, evenly.
- `local` — prefer healthy backends in the *local* cluster; only route to a
  remote cluster's backends if every local backend is unhealthy. This is the
  common "keep traffic close unless we have to fail over" pattern.
- `remote` — the inverse: prefer the *other* cluster's backends, falling
  back to local only if all remote backends are unhealthy.

This is exactly the same class of decision an LLM-serving platform makes
when choosing which regional inference cluster should answer a request by
default versus only under failover — Cluster Mesh's affinity annotation is
the CNI-level primitive for expressing that same "prefer close, fail over
far" policy for any Service, without an external global load balancer.

Cilium's own troubleshooting tooling makes the effective preference directly
observable: `cilium-dbg service list --clustermesh-affinity`, run inside a
Cilium agent, marks each backend `(preferred)` or not, based on the
Service's `affinity` annotation and each backend's live health — which is
the debugging path you'd reach for in a real, multi-cluster mesh once this
is configured.

## Scope limitation — read this before starting

**This environment has only one real Kubernetes cluster** (1 control-plane +
2 workers). There is no second cluster's backends to actually load-balance
to, and this lab does not attempt to fake one. What this lab exercises
instead:

- Confirming the `clustermesh-apiserver` control-plane precondition is
  healthy (same as ATM-06 — deploying it is a cluster-wide, singleton
  change, which is why both labs use the same `clustermesh` lock and never
  run at the same time).
- Correctly setting a Service's affinity annotation to express the required
  "prefer local, fail over to remote" policy.

It deliberately does **not** claim to prove requests actually get
distributed local-first — that would require a second real cluster with its
own backends to observe traffic landing on. What it proves: the Service is
*configured* to apply that policy correctly the moment a real mesh exists.
