# Hints — OBS-05

## Level 1

Confirm both Pods actually have the sidecar, and look at what's already
configured:

```bash
kubectl -n ckne-obs-05 get pods -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].name}{"\n"}{end}'
kubectl -n ckne-obs-05 get telemetry access-logging -o yaml
kubectl -n ckne-obs-05 get configmap trace-reporter-config -o yaml
```

Send one request and check for a log line — is anything showing up at all
in `istio-proxy`'s own logs?

```bash
kubectl -n ckne-obs-05 exec client -c client -- wget -qO- http://backend.ckne-obs-05.svc.cluster.local/test
kubectl -n ckne-obs-05 logs deployment/backend -c istio-proxy --tail=50
```

## Level 2

For access logs: Istio ships exactly one provider that needs no extra
cluster-wide setup. Compare the `providers[].name` in `access-logging`
against Istio's Telemetry API reference — is it spelled exactly right?

For tracing: `trace-reporter-config` names a Jaeger Service and port. List
every port Jaeger's Services actually expose in `observability`:

```bash
kubectl -n observability get svc -o wide
```

Which port in that list is the plain HTTP/JSON (Zipkin-compatible) one —
and does it match `JAEGER_COLLECTOR_PORT`?

## Level 3

```bash
kubectl -n ckne-obs-05 patch telemetry access-logging --type=json \
  -p '[{"op":"replace","path":"/spec/accessLogging/0/providers/0/name","value":"envoy"}]'

kubectl -n ckne-obs-05 get configmap trace-reporter-config -o jsonpath='{.data.JAEGER_COLLECTOR_PORT}'
```

Jaeger's Zipkin-compatible span ingest port is a well-known, fixed value —
look it up in the Jaeger APIs docs if you're not sure, then patch the
ConfigMap and re-submit a span from `client`.
