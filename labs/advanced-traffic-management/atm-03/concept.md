# Concept: Weighted Traffic Splitting with the Gateway API

An `HTTPRoute` rule can list more than one `backendRefs` entry. When it
does, each entry may carry a `weight` (an integer, default `1` if omitted).
The implementation distributes matching requests across the listed
backends in proportion to `weight / sum(all weights in the rule)` — it is
a *ratio*, not an absolute percentage, so `weight: 80`/`weight: 20` behaves
identically to `weight: 8`/`weight: 2` or `weight: 4`/`weight: 1`. This is
the standard mechanism behind canary releases and blue/green rollouts
driven purely through the Gateway API, with no service mesh required: point
one Service at the old version, one at the new version, and shift the
weight over time (or automate it with a progressive-delivery controller
layered on top, which is out of scope for this lab).

Because the split is enforced per-request by the data plane (Envoy, in
Cilium's case) using its own internal random selection, it is statistically
accurate over a large number of requests but **not** deterministic over a
small sample — sending exactly 40 requests at an 80/20 configuration will
not reliably land on exactly 32/8. Treat weighted splitting as "shifts the
long-run average," not "guarantees this exact request goes here."
