# Hints — OBS-04

## Level 1

Confirm the app itself is healthy and reachable through its Service before
suspecting Prometheus:

```bash
kubectl -n ckne-obs-04 get pods -o wide
kubectl -n ckne-obs-04 run check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- http://netmetrics.ckne-obs-04.svc.cluster.local:8080/metrics
```

If that works, the app is fine — so where would Prometheus's own scrape
config for auto-discovering this target actually come from?

## Level 2

```bash
kubectl -n ckne-obs-04 get svc netmetrics -o yaml | grep -A3 annotations
```

Compare the `prometheus.io/port` value against the Service's own
`spec.ports` / the container's actual listening port
(`kubectl -n ckne-obs-04 get deployment netmetrics -o yaml | grep -A2 containerPort`).

## Level 3

Fix the annotation, generate a few hits, then query Prometheus directly —
don't guess, ask it:

```bash
kubectl -n ckne-obs-04 run hit --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- http://netmetrics.ckne-obs-04.svc.cluster.local:8080/hit

kubectl -n ckne-obs-04 run promql-check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs04_requests_total"
```

Prometheus scrapes on an interval, not instantly — if `"result":[]` right
after fixing the annotation, wait a bit and try again before assuming the
fix didn't work.
