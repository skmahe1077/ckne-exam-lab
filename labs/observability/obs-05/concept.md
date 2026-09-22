# Concept: Envoy Access Logs and Distributed Tracing

Istio works by injecting an `istio-proxy` (Envoy) sidecar container into
every Pod in a namespace labeled `istio-injection: enabled`. iptables rules
inside the Pod's network namespace transparently redirect both inbound and
outbound traffic through that sidecar, which means Envoy sees — and can
record — every request the Pod sends or receives, regardless of whether the
*other* end of the connection is itself part of the mesh.

**Access logs** are Envoy's per-request log lines: method, path, response
code, latency, upstream host, and more, written to the sidecar container's
stdout (readable via `kubectl logs <pod> -c istio-proxy`). Istio does not
turn this on by default — you opt in via the `Telemetry` API's
`accessLogging` field, referencing a **provider**. Istio pre-registers one
provider automatically in every install, literally named `envoy` (plain
stdout logging, Envoy's own default text format) — referencing it needs no
extra mesh-wide configuration. Custom providers (OpenTelemetry collectors,
Stackdriver, etc.) are different: those must first be registered in
`meshConfig.extensionProviders`, a cluster-wide setting, before any
`Telemetry` object can reference them by name. A `Telemetry` object with no
`selector` applies to every workload in its own namespace — which is why a
single namespaced object is enough to turn on access logging for this whole
lab, without touching shared mesh config or needing a lock.

**Distributed tracing** works differently: it correlates multiple spans
(one per hop) into a single trace using a shared trace ID, normally
propagated automatically by Envoy via a header (`traceparent`/`b3`) and
reported to a tracing backend Istio's mesh config points it at. Wiring that
up mesh-wide also requires a cluster-scoped `extensionProviders` entry
(exactly the kind of shared, cluster-singleton configuration a single lab
should not mutate outside a lock — see `shared/scripts/lock.sh`). This lab
sidesteps that by submitting a span **directly** to Jaeger's own
Zipkin-compatible HTTP ingest API (`POST /api/v2/spans`, plain JSON) from
inside the mesh namespace, and then reading it back from Jaeger's Query API
(`GET /api/traces?service=...`) — the same fundamental skill (submit a
trace, query it back by service name) without requiring a cluster-wide
tracing pipeline to already exist.

One practical Istio gotcha this lab's scripts route around: a sidecar
container never exits on its own, so a throwaway `kubectl run --rm
--restart=Never` Pod created inside a mesh-injected namespace would get
`istio-proxy` injected too — and then hang forever, because
`restartPolicy: Never` waits for *every* container to exit, and
`istio-proxy` won't. `kubectl exec` into an already-running Pod's existing
container sidesteps this entirely: no new Pod, no injection, no hang.
