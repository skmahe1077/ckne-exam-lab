# Solution — SVC-05

## Diagnosis

1. The StatefulSet is healthy — not the problem:

   ```bash
   kubectl -n ckne-svc-05 get statefulset web
   # READY 3/3
   ```

2. The governing Service has a real ClusterIP, not `None`:

   ```bash
   kubectl -n ckne-svc-05 get svc web -o jsonpath='{.spec.clusterIP}{"\n"}'
   ```

3. Per-Pod DNS lookups don't return each Pod's own IP:

   ```bash
   kubectl -n ckne-svc-05 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
     --command -- nslookup web-0.web.ckne-svc-05.svc.cluster.local
   ```

   Because the Service isn't headless, CoreDNS never publishes per-Pod
   records for it at all — this lookup fails outright (NXDOMAIN), even
   though the StatefulSet and its Pods are completely healthy.

## Fix

`clusterIP` is immutable, so the Service must be deleted and recreated as
headless (see `manifests/expected/service.yaml`):

```bash
kubectl -n ckne-svc-05 delete svc web
kubectl apply -f manifests/expected/service.yaml   # after sed-substituting ${NAMESPACE}/${TASK_ID}
```

## Verify

```bash
kubectl -n ckne-svc-05 get svc web -o jsonpath='{.spec.clusterIP}{"\n"}'
# None

for i in 0 1 2; do
  kubectl -n ckne-svc-05 run dns-check-$i --image=busybox:1.36 --restart=Never --rm -i \
    --command -- nslookup web-$i.web.ckne-svc-05.svc.cluster.local
  kubectl -n ckne-svc-05 get pod web-$i -o jsonpath='{.status.podIP}{"\n"}'
done

make validate LAB=SVC-05
```

Each `web-<N>.web.ckne-svc-05.svc.cluster.local` lookup should now return
exactly that Pod's own `status.podIP` — proving CoreDNS is publishing
individual per-Pod records instead of a shared VIP.
