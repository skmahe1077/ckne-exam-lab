# Hints — SVC-05

## Level 1

```bash
kubectl -n ckne-svc-05 get statefulset web
kubectl -n ckne-svc-05 get svc web -o yaml
```

The StatefulSet is healthy. Look at the Service's `spec.clusterIP` — is it
`None`, or an actual IP address?

## Level 2

Try resolving a specific Pod's DNS name and see what comes back:

```bash
kubectl -n ckne-svc-05 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
  --command -- nslookup web-0.web.ckne-svc-05.svc.cluster.local
kubectl -n ckne-svc-05 get pod web-0 -o jsonpath='{.status.podIP}{"\n"}'
```

Does the resolved address match `web-0`'s actual Pod IP, or does it look
like something else (or fail entirely)?

## Level 3

`clusterIP` cannot be patched on an existing Service — it's immutable.
You need to delete and recreate it as headless:

```bash
kubectl -n ckne-svc-05 delete svc web
kubectl -n ckne-svc-05 apply -f manifests/expected/service.yaml   # after sed-substituting ${NAMESPACE}/${TASK_ID}
```

Then re-run the `nslookup` check for `web-0`, `web-1`, and `web-2` against
each Pod's own `status.podIP`.
