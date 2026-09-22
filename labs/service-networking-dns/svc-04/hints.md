# Hints — SVC-04

## Level 1

```bash
kubectl -n ckne-svc-04 get svc docs -o yaml
```

Look specifically at `spec.externalName`. Does that hostname look like
something that could plausibly exist on the public internet?

## Level 2

Try resolving it yourself from inside the cluster, the same way a Pod
would:

```bash
kubectl -n ckne-svc-04 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
  --command -- nslookup docs.ckne-svc-04.svc.cluster.local
```

What does the CNAME chain point to, and does that final name resolve?

## Level 3

```bash
kubectl -n ckne-svc-04 patch svc docs --type=merge -p '{"spec":{"externalName":"kubernetes.io"}}'
```

`kubernetes.io` is a real, stable public domain — re-run the `nslookup`
check above and confirm the CNAME now resolves all the way through.
