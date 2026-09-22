# Concept: Prometheus Metrics for Network Components

Prometheus works by **pulling** — it periodically sends an HTTP GET to a
`/metrics` endpoint on every target it knows about and parses whatever
plain-text, line-based exposition format comes back (`# HELP`, `# TYPE`,
then `metric_name{labels} value` lines). A target is just "a host:port and a
path"; Prometheus itself has no idea what's behind it until it scrapes.

**How targets are discovered.** The shared `prometheus-community/prometheus`
chart installed in this cluster uses Kubernetes service discovery
(`kubernetes_sd_configs`) with a default job, `kubernetes-service-endpoints`,
that watches every Service's Endpoints and auto-discovers a scrape target
for any Service annotated:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"      # which port to scrape
  prometheus.io/path: "/metrics"  # defaults to /metrics if omitted
```

This is convenient — no separate CRD or config change needed per
application — but it means a single wrong digit in `prometheus.io/port`
silently produces "no error, no metric, nothing to grep in a log": the
scrape target either doesn't get created at all (if `scrape` isn't `"true"`)
or gets created pointing at the wrong port, in which case Prometheus's
*own* internal `up{}` metric for that target would report `0` — but if
nothing was ever collected for that exact `job`/`instance` combination
because the endpoint was simply wrong, you may not even find a stale `up`
series to look at. The fastest way to tell "is my metric actually flowing"
is not to guess from the app side — it's to ask Prometheus directly via its
HTTP query API:

```
GET /api/v1/query?query=<promql>
```

against `prometheus-server.monitoring.svc.cluster.local`. A `"result":[]`
in the JSON response means Prometheus has never successfully collected that
metric — full stop. This is the discipline the lab exercises: don't infer
whether metrics are flowing from whether the Pod is Running, or from
reading YAML and assuming the annotation is right — ask Prometheus's own
query API, which only ever returns data it actually scraped.

The same mechanism applies to core cluster network components. `kube-apiserver`
exposes `apiserver_request_total` (a counter of every API request, labeled
by verb/resource/code) — every `kubectl` command anyone runs against the
cluster increments it. Because every lab's setup/validate scripts, and every
`kubectl` invocation a student runs, all go through the API server, this
metric is a reliable, always-non-zero signal that Prometheus itself is
healthy — independent of whatever your own app's scrape config is doing.
