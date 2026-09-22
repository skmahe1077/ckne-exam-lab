# Solution — SVC-01

## Diagnosis

1. The `api` Deployment is already 2/2 Ready — this is not a Pod problem:

   ```bash
   kubectl -n ckne-svc-01 get deployment api
   ```

2. The Service has no Endpoints:

   ```bash
   kubectl -n ckne-svc-01 get endpoints api
   # api   <none>
   ```

3. The Service's selector (`app: apiserver`) does not match the Pod
   template's actual label (`app: api`):

   ```bash
   kubectl -n ckne-svc-01 get svc api -o jsonpath='{.spec.selector}{"\n"}'
   kubectl -n ckne-svc-01 get pods --show-labels
   ```

## Fix

Correct the Service's selector to match the Pods (see
`manifests/expected/service.yaml` for the full corrected object):

```bash
kubectl -n ckne-svc-01 patch svc api --type=merge -p '{"spec":{"selector":{"app":"api"}}}'
```

## Verify

```bash
kubectl -n ckne-svc-01 get endpoints api
make validate LAB=SVC-01
```

Endpoints should now list both Pod IPs on port 80, and a request to the
Service's ClusterIP should succeed.
