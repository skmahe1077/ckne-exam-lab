# CKNE-OBS-05 — Solution

## Root cause

**Access logging:** the `access-logging` `Telemetry` object's provider name is `envoy-log`, which does not exist — Istio's real, pre-registered built-in provider is named `envoy`. **Tracing:** `trace-reporter-config`'s `JAEGER_COLLECTOR_PORT` is `14250`, Jaeger's gRPC collector port, which does not accept plain HTTP+JSON POSTs; the Zipkin-compatible HTTP/JSON ingest port is `9411`.

## Investigation process

Confirm both Pods have the sidecar, and check what's already configured:

```bash
kubectl -n ckne-obs-05 get pods -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].name}{"\n"}{end}'
kubectl -n ckne-obs-05 get telemetry access-logging -o yaml
kubectl -n ckne-obs-05 get configmap trace-reporter-config -o yaml
```

Send one request and check for a log line:

```bash
kubectl -n ckne-obs-05 exec client -c client -- wget -qO- http://backend.ckne-obs-05.svc.cluster.local/test
kubectl -n ckne-obs-05 logs deployment/backend -c istio-proxy --tail=50
# (no HTTP access log line for /test)
```

`providers[0].name: envoy-log` in the Telemetry object is not a real Istio provider name — the only one available without a cluster-wide `meshConfig.extensionProviders` change is `envoy`.

For tracing, list Jaeger's real Service ports:

```bash
kubectl -n observability get svc -o wide
```

`trace-reporter-config` shows `JAEGER_COLLECTOR_PORT: "14250"` — Jaeger's gRPC collector port, not the Zipkin-compatible HTTP/JSON port (`9411`).

## Corrected configuration

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: access-logging
  namespace: ckne-obs-05
spec:
  accessLogging:
    - providers:
        - name: envoy
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trace-reporter-config
  namespace: ckne-obs-05
data:
  JAEGER_QUERY_SVC: "<discovered by setup.sh>"
  JAEGER_QUERY_PORT: "16686"
  JAEGER_COLLECTOR_SVC: "<discovered by setup.sh>"
  JAEGER_COLLECTOR_PORT: "9411"
```

Equivalent inline patches:

```bash
kubectl -n ckne-obs-05 patch telemetry access-logging --type=json \
  -p '[{"op":"replace","path":"/spec/accessLogging/0/providers/0/name","value":"envoy"}]'

kubectl -n ckne-obs-05 patch configmap trace-reporter-config --type=json \
  -p '[{"op":"replace","path":"/data/JAEGER_COLLECTOR_PORT","value":"9411"}]'
```

## Verification steps

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

## Why this works

Istio's `istio-proxy` sidecar sees every request a Pod sends or receives because iptables transparently redirects traffic through it, but access logging isn't on by default — a `Telemetry` object's `accessLogging.providers` must reference a real provider name. Istio pre-registers exactly one provider, literally named `envoy`, that needs no extra mesh-wide configuration; any other name (including a plausible-looking typo like `envoy-log`) silently matches nothing, so no log lines ever appear despite the sidecar being fully healthy. Because the `Telemetry` object has no `selector`, it applies to every workload in its own namespace once the provider name is correct — no shared mesh config or lock needed. Separately, distributed tracing here bypasses the mesh-wide tracing pipeline (which would require a cluster-scoped `extensionProviders` entry) by submitting spans directly to Jaeger's Zipkin-compatible HTTP ingest API — but that only works against Jaeger's actual HTTP/JSON port (`9411`); pointing at the gRPC collector port (`14250`) means the plain JSON `POST` never speaks a protocol that port understands, so submission fails silently from the app's perspective. Fixing both values doesn't touch Istio or Jaeger's shared installations at all — both fixes are narrow, namespace-scoped configuration corrections.

## Faster exam-oriented method

Two independent one-line checks: `kubectl get telemetry access-logging -o yaml` for the provider name (should read exactly `envoy`), and `kubectl get configmap trace-reporter-config -o jsonpath='{.data.JAEGER_COLLECTOR_PORT}'` compared against Jaeger's known Zipkin ingest port (`9411`, a fixed, well-known value). Two JSON patches fix both; no deeper investigation needed since both Pods already have healthy sidecars.

## Common mistakes

- Modifying `meshConfig.extensionProviders` or any other cluster-wide Istio/Jaeger setting to "properly" register a provider — unnecessary and disallowed; the built-in `envoy` provider needs zero extra registration, and both fixes here are meant to stay namespace-scoped.
- Assuming no access log lines or no traces means the mesh/tracing stack itself is down, and spending time investigating istiod or Jaeger's health — both are healthy preconditions; the actual faults are two small, specific configuration values.
- Creating a throwaway `kubectl run --rm --restart=Never` Pod inside the mesh-injected namespace to test connectivity — it gets `istio-proxy` injected too and hangs forever, since `restartPolicy: Never` waits for every container to exit and the sidecar never does on its own; `kubectl exec` into the already-running `client` Pod avoids this entirely.
- Submitting a span to Jaeger's gRPC port instead of its Zipkin-compatible HTTP port, or using the wrong request format — a plain JSON `POST` only works against `9411`'s `/api/v2/spans` endpoint, not the gRPC collector.

## Relevant documentation

- Istio access logging — https://istio.io/latest/docs/tasks/observability/logs/access-log/
- Istio Telemetry API reference — https://istio.io/latest/docs/reference/config/telemetry/
- Istio distributed tracing overview — https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/
- Jaeger APIs — https://www.jaegertracing.io/docs/latest/apis/
- Envoy access log configuration — https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/access_log
