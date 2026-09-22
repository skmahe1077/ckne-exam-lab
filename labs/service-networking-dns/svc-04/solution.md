# Solution — SVC-04

## Diagnosis

1. The Service is `type: ExternalName` pointing at a domain that was never
   registered:

   ```bash
   kubectl -n ckne-svc-04 get svc docs -o jsonpath='{.spec.externalName}{"\n"}'
   # kubernetes-docs.invalid.nonexistent-ckne-lab-domain.test
   ```

2. Confirm the failure from inside the cluster:

   ```bash
   kubectl -n ckne-svc-04 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
     --command -- nslookup docs.ckne-svc-04.svc.cluster.local
   # ** server can't find ...: NXDOMAIN
   ```

## Fix

Point `externalName` at a real, stable public DNS name (see
`manifests/expected/service.yaml`):

```bash
kubectl -n ckne-svc-04 patch svc docs --type=merge \
  -p '{"spec":{"externalName":"kubernetes.io"}}'
```

## Verify

```bash
kubectl -n ckne-svc-04 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
  --command -- nslookup docs.ckne-svc-04.svc.cluster.local
# Name should resolve, with a CNAME to kubernetes.io in the chain

make validate LAB=SVC-04
```

Because `ExternalName` Services are pure DNS aliases (CoreDNS's
`kubernetes` plugin answers with a CNAME and lets the `forward` plugin
resolve the rest upstream), fixing this required no selector, no ports,
and no Endpoints — only the DNS target itself.
