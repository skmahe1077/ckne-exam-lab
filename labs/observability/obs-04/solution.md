# CKNE-OBS-04 — Solution

## Root cause

The `netmetrics` Service's `prometheus.io/port` annotation is `"9090"`, but the container only ever listens on and serves `/metrics` on port `8080`. Prometheus's `kubernetes-service-endpoints` scrape job was told to scrape a port nothing serves, so `obs04_requests_total` never appears in Prometheus — even though normal Service traffic to the app on port 8080 works perfectly fine.

## Investigation process

Confirm the app itself is healthy and reachable through its Service before suspecting Prometheus:

```bash
kubectl -n ckne-obs-04 get pods -o wide
kubectl -n ckne-obs-04 run check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- http://netmetrics.ckne-obs-04.svc.cluster.local:8080/metrics
# obs04_requests_total 0
```

The app is fine — so check where Prometheus's scrape config for this target actually comes from:

```bash
kubectl -n ckne-obs-04 get svc netmetrics -o yaml | grep -A3 annotations
# prometheus.io/port: "9090"
```

Compare against the container's actual listening port:

```bash
kubectl -n ckne-obs-04 get deployment netmetrics -o yaml | grep -A2 containerPort
# containerPort: 8080
```

The annotation and the real port don't match.

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: netmetrics
  namespace: ckne-obs-04
  labels:
    app: netmetrics
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "8080"
spec:
  selector:
    app: netmetrics
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

Equivalent inline command:

```bash
kubectl -n ckne-obs-04 annotate svc netmetrics prometheus.io/port=8080 --overwrite
```

## Verification steps

Generate real traffic through the Service, then ask Prometheus directly:

```bash
for i in 1 2 3; do
  kubectl -n ckne-obs-04 run hit-$i --image=busybox:1.36 --rm -it --restart=Never \
    -- wget -qO- http://netmetrics.ckne-obs-04.svc.cluster.local:8080/hit
done

kubectl -n ckne-obs-04 run promql-check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs04_requests_total"
# {"status":"success","data":{"resultType":"vector","result":[{"metric":{...},"value":[..., "3"]}]}}

kubectl -n ckne-obs-04 run promql-apiserver --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=apiserver_request_total"

make validate LAB=OBS-04
```

## Why this works

Prometheus works by pulling: it periodically GETs `/metrics` on every target it discovers and parses whatever comes back. The shared server's `kubernetes-service-endpoints` job auto-discovers scrape targets purely from a Service's `prometheus.io/*` annotations — a single wrong digit in `prometheus.io/port` produces no error, no log line, nothing to grep; the scrape target simply points at a port nothing serves, and the metric silently never appears. Correcting the annotation to `8080` gives Prometheus the real port, and on its next scrape interval it starts collecting `obs04_requests_total`. Because `apiserver_request_total` is incremented by every `kubectl` command anyone runs and is always non-zero on a healthy cluster, querying it independently proves Prometheus itself was never broken — only this one target's discovery config was wrong. The only reliable way to confirm a metric is flowing is to ask Prometheus's own HTTP API directly (`GET /api/v1/query`) rather than inferring from Pod status or trusting the YAML annotation is correct.

## Faster exam-oriented method

`kubectl get svc netmetrics -o yaml | grep -A3 annotations` next to `containerPort` on the Deployment — a mismatched `prometheus.io/port` is the entire diagnosis. `kubectl annotate --overwrite` fixes it in one command; querying Prometheus's API afterward is how you prove it, not how you find it.

## Common mistakes

- Modifying the `netmetrics` Deployment, ConfigMap, or container port to "match" the wrong annotation instead of fixing the annotation itself — the container's port (8080) was always correct; only the Service's scrape annotation was wrong.
- Concluding Prometheus itself is broken because a metric is missing, and going to inspect/restart the shared Prometheus server — it's a cluster-wide resource used by every other lab and was never the fault here; a missing metric from one target almost always means a target/discovery misconfiguration, not a Prometheus outage.
- Checking `"result":[]` immediately after fixing the annotation and assuming the fix failed — Prometheus scrapes on an interval, not instantly; waiting for the next scrape cycle before re-querying is expected.
- Generating traffic by port-forwarding directly into the Pod instead of through the Service — the task specifically requires exercising the Service, since scraping and normal traffic both depend on the Service's port configuration being correct end-to-end.

## Relevant documentation

- Prometheus HTTP API — https://prometheus.io/docs/prometheus/latest/querying/api/
- Prometheus querying basics — https://prometheus.io/docs/prometheus/latest/querying/basics/
- Prometheus Kubernetes service discovery — https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config
- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
