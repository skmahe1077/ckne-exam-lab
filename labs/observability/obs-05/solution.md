# Solution — OBS-05

## Diagnosis

1. Both Pods have the sidecar, but no access log lines appear for a real
   request:

   ```bash
   kubectl -n ckne-obs-05 exec client -c client -- wget -qO- http://backend.ckne-obs-05.svc.cluster.local/test
   kubectl -n ckne-obs-05 logs deployment/backend -c istio-proxy --tail=50
   # (no HTTP access log line for /test)
   ```

2. `kubectl -n ckne-obs-05 get telemetry access-logging -o yaml` shows
   `providers[0].name: envoy-log` — not a real Istio provider name (the
   only one available without a cluster-wide `meshConfig.extensionProviders`
   change is `envoy`).

3. `kubectl -n observability get svc -o wide` lists Jaeger's exposed ports.
   `kubectl -n ckne-obs-05 get configmap trace-reporter-config -o yaml`
   shows `JAEGER_COLLECTOR_PORT: "14250"` — Jaeger's gRPC collector port,
   which does not accept plain HTTP+JSON POSTs. The Zipkin-compatible
   HTTP/JSON ingest port is `9411`.

## Fix

```bash
kubectl -n ckne-obs-05 patch telemetry access-logging --type=json \
  -p '[{"op":"replace","path":"/spec/accessLogging/0/providers/0/name","value":"envoy"}]'

kubectl -n ckne-obs-05 patch configmap trace-reporter-config --type=json \
  -p '[{"op":"replace","path":"/data/JAEGER_COLLECTOR_PORT","value":"9411"}]'
```

See `manifests/expected/telemetry.yaml` and
`manifests/expected/trace-reporter-config.yaml` for the full corrected
objects (the Jaeger Service names are cluster-specific and discovered by
`setup.sh` at apply time — only the provider name and collector port are
what you need to fix).

## Verify

```bash
kubectl -n ckne-obs-05 exec client -c client -- wget -qO- http://backend.ckne-obs-05.svc.cluster.local/verify
kubectl -n ckne-obs-05 logs deployment/backend -c istio-proxy --tail=50 | grep verify
# a real access log line for /verify now appears

QUERY_SVC="$(kubectl -n ckne-obs-05 get configmap trace-reporter-config -o jsonpath='{.data.JAEGER_QUERY_SVC}')"
COLLECTOR_SVC="$(kubectl -n ckne-obs-05 get configmap trace-reporter-config -o jsonpath='{.data.JAEGER_COLLECTOR_SVC}')"

kubectl -n ckne-obs-05 exec client -c client -- wget -qO- \
  --header="Content-Type: application/json" \
  --post-data='[{"id":"0000000000000001","traceId":"00000000000000000000000000000001","name":"manual-check","timestamp":1700000000000000,"duration":1000,"localEndpoint":{"serviceName":"obs05-client"},"tags":{"nonce":"manual"}}]' \
  "http://${COLLECTOR_SVC}.observability.svc.cluster.local:9411/api/v2/spans"

kubectl -n ckne-obs-05 exec client -c client -- wget -qO- \
  "http://${QUERY_SVC}.observability.svc.cluster.local:16686/api/traces?service=obs05-client&lookback=1h&limit=20" | grep manual

make validate LAB=OBS-05
```

Neither Istio nor Jaeger themselves were ever broken — the exercise is
precisely that "no logs/no traces" from a fully-injected, fully-healthy
mesh almost always traces back to a small, specific configuration
reference (a provider name, a port number) rather than the observability
stack itself being down.
