Task ID: OBS-05
Domain: Observability
Difficulty: advanced
Estimated time: 35 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-obs-05

Scenario:
  The `ckne-obs-05` namespace is labeled `istio-injection: enabled`, and a
  `backend` Deployment/Service plus a persistent `client` Pod are both
  running with an `istio-proxy` sidecar injected. Two things were set up to
  make this Envoy/Jaeger observable, and both are broken:
  - A `Telemetry` object, `access-logging`, is supposed to turn on Envoy
    access logging for every workload in the namespace using Istio's
    built-in `envoy` provider — but its provider name has a typo, so no
    access log lines are being produced yet.
  - A ConfigMap, `trace-reporter-config`, holds the Service name/port this
    lab uses to submit and query real trace spans against the cluster's
    shared Jaeger install (in the `observability` namespace) — but the
    collector port is wrong (it points at Jaeger's gRPC port instead of its
    Zipkin-compatible HTTP/JSON port), so span submission fails.

Objective:
  Fix both misconfigurations, then prove — with real requests and real
  queries, not by reading YAML — that Envoy is now logging access lines for
  requests you make, and that a real trace you submit is queryable back out
  of Jaeger's own API.

Requirements:
  1. Do not modify the `backend` Deployment/Service, the `client` Pod, or
     the namespace's `istio-injection` label.
  2. Fix the `access-logging` Telemetry object's provider name so it
     references Istio's real, built-in `envoy` access-log provider (no
     cluster-wide Istio config change is needed or allowed — this must stay
     a namespace-scoped fix).
  3. Send a real HTTP request from `client` to `backend`
     (`kubectl -n ckne-obs-05 exec client -c client -- wget -qO- http://backend.ckne-obs-05.svc.cluster.local/<anything>`)
     and confirm an access log line for it appears in backend's
     `istio-proxy` container logs:
     `kubectl -n ckne-obs-05 logs deployment/backend -c istio-proxy --tail=200`
  4. Fix `trace-reporter-config`'s `JAEGER_COLLECTOR_PORT` so span
     submission actually reaches Jaeger's Zipkin-compatible ingest
     endpoint.
  5. Submit a real span from `client` to
     `http://<collector-svc>.observability.svc.cluster.local:<port>/api/v2/spans`
     (Zipkin v2 JSON format), then query Jaeger's own Query API
     (`http://<query-svc>.observability.svc.cluster.local:16686/api/traces?service=obs05-client`)
     and confirm your span is actually returned.
  6. Do not modify the shared Istio or Jaeger installations — they are
     cluster-wide resources used by every other lab.

Verification criteria:
  - istiod (istio-system) and Jaeger (observability) are Ready
    (preconditions, not something you are asked to change).
  - `ckne-obs-05` still carries `istio-injection=enabled`.
  - `backend` is `1/1` Ready and both `backend` and `client` have an
    `istio-proxy` sidecar container.
  - A real request from `client` to `backend` produces a matching access
    log line in `backend`'s `istio-proxy` logs.
  - A real span submitted from `client` to Jaeger's collector succeeds
    (HTTP 2xx / no connection error).
  - Jaeger's Query API returns a trace containing that submitted span when
    queried for `service=obs05-client`.
