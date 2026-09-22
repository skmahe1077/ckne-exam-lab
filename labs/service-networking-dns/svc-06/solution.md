# Solution — SVC-06

## Diagnosis

1. Both `web` Pods are `Running` but `0/2` Ready:

   ```bash
   kubectl -n ckne-svc-06 get pods -l app=web -o wide
   ```

2. `kubectl -n ckne-svc-06 describe pod -l app=web` shows repeating Events
   like:

   ```
   Warning  Unhealthy  ...  Readiness probe failed: HTTP probe failed with statuscode: 404
   ```

3. The Deployment's `readinessProbe` is:

   ```yaml
   readinessProbe:
     httpGet:
       path: /healthz
       port: 80
   ```

   `nginx:1.27`'s default image does not serve anything at `/healthz` — it
   404s. The container is healthy and serving traffic on `/`, but the probe
   is checking the wrong path.

4. Because the Pods are never Ready, the EndpointSlice for `web` either
   omits them or lists them with `conditions.ready: false`:

   ```bash
   kubectl -n ckne-svc-06 get endpointslice -l kubernetes.io/service-name=web -o yaml
   ```

## Fix

Point the probe at a path nginx actually serves with 2xx (see
`manifests/expected/deployment.yaml`):

```bash
kubectl -n ckne-svc-06 patch deployment web --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

## Verify

```bash
kubectl -n ckne-svc-06 rollout status deployment/web
kubectl -n ckne-svc-06 get endpointslice -l kubernetes.io/service-name=web -o yaml
make validate LAB=SVC-06
```

Once both Pods pass the probe, the EndpointSlice controller adds their
addresses with `conditions.ready: true`, and kube-proxy/Cilium start
routing Service traffic to them — the Service object itself never needed
to change.
