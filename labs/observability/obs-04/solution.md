# Solution — OBS-04

## Diagnosis

1. The app itself is healthy and reachable through its Service:

   ```bash
   kubectl -n ckne-obs-04 run check --image=busybox:1.36 --rm -it --restart=Never \
     -- wget -qO- http://netmetrics.ckne-obs-04.svc.cluster.local:8080/metrics
   # obs04_requests_total 0
   ```

2. But Prometheus has never scraped it — its scrape annotation points at
   the wrong port:

   ```bash
   kubectl -n ckne-obs-04 get svc netmetrics -o yaml | grep -A3 annotations
   # prometheus.io/port: "9090"
   ```

   The container only listens on 8080 (see `spec.ports` on the same
   Service, and `containerPort: 8080` on the Deployment) — Prometheus's
   `kubernetes-service-endpoints` job was told to scrape a port nothing
   serves.

## Fix

Correct the annotation (see `manifests/expected/netmetrics-service.yaml`):

```bash
kubectl -n ckne-obs-04 annotate svc netmetrics prometheus.io/port=8080 --overwrite
```

## Verify

Generate real traffic, then ask Prometheus directly:

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

Prometheus itself and its scrape *mechanism* were never broken — the
exercise is precisely that a metric silently missing from Prometheus is
usually a target/discovery misconfiguration (a wrong annotation), not a
Prometheus outage, and the only reliable way to tell the difference is to
query Prometheus's own API rather than inspect the app or infer from Pod
status.
