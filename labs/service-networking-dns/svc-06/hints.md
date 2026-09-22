# Hints — SVC-06

## Level 1

Start with the Pods, not the Service:

```bash
kubectl -n ckne-svc-06 get pods -l app=web -o wide
```

`STATUS` should say `Running`, but `READY` will not say `2/2`. A container
that is Running but not Ready almost always means a probe is failing —
check which kind.

## Level 2

Ask Kubernetes directly what the probe is doing:

```bash
kubectl -n ckne-svc-06 describe pod -l app=web
```

Read the `Events` section — a failing `readinessProbe` logs the exact HTTP
status code it got back. Then look at what the probe is actually
configured to check:

```bash
kubectl -n ckne-svc-06 get deployment web -o yaml | grep -A6 readinessProbe
```

Also look at the EndpointSlice while the Pods are still not Ready — this
is what "invisible to the Service" looks like at the API level:

```bash
kubectl -n ckne-svc-06 get endpointslice -l kubernetes.io/service-name=web -o yaml
```

## Level 3

The probe is an `httpGet` against a specific `path` on port 80. nginx's
default image (this Deployment uses `nginx:1.27`, unmodified) only serves
a 200 on the document root. Does the configured `path` match that? Fix
only the probe's `path` field — nothing else in the Deployment or the
Service needs to change.
