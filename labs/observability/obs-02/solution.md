# Solution — OBS-02

## Diagnosis

1. CoreDNS's logs show nothing related to `orders` or `ckne-obs-02` — no
   SERVFAILs, no forwarding errors:

   ```bash
   kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100
   ```

2. DNS resolution of the Service name succeeds even though the app is
   broken — confirming DNS is not the problem:

   ```bash
   kubectl -n ckne-obs-02 run dns-check --image=busybox:1.36 --rm -it --restart=Never \
     -- nslookup orders.ckne-obs-02.svc.cluster.local
   # Name:   orders.ckne-obs-02.svc.cluster.local
   # Address: 10.96.x.x
   ```

3. `kubectl -n ckne-obs-02 get endpoints orders` shows an empty
   `ENDPOINTS` column, and `kubectl -n ckne-obs-02 get pods` shows the
   `orders` Pods as `0/1 Running` (not `0/1 CrashLoopBackOff` — the
   container is alive, it's just never marked Ready).

4. `kubectl -n ckne-obs-02 describe pod -l app=orders` shows repeated
   `Warning  Unhealthy  Readiness probe failed: HTTP probe failed with
   statuscode: 404` events — the probe checks `GET /healthz`, but a
   default `nginx:1.27` image never serves that path.

## Fix

Change the readinessProbe's path to `/` (see
`manifests/expected/orders.yaml` for the full corrected object):

```bash
kubectl -n ckne-obs-02 patch deployment orders --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

## Verify

```bash
kubectl -n ckne-obs-02 rollout status deployment/orders
kubectl -n ckne-obs-02 get endpoints orders
make validate LAB=OBS-02
```

CoreDNS was never the problem — the exercise is precisely that "nothing
reaches the Service" does not automatically implicate DNS; an empty
Endpoints list with working name resolution points at Pod readiness
instead.
