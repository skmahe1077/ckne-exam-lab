# Solution — ATM-06

## Diagnosis

1. The control-plane precondition is already satisfied:

   ```bash
   kubectl -n kube-system get deployment clustermesh-apiserver
   kubectl -n kube-system get secret clustermesh-apiserver-server-cert -o jsonpath='{.data}'
   ```

2. `catalog`'s Deployment is Ready and its Service routes traffic normally
   within this cluster, but its annotations don't mention
   `service.cilium.io` at all:

   ```bash
   kubectl -n ckne-atm-06 get svc catalog -o jsonpath='{.metadata.annotations}{"\n"}'
   ```

   Without `service.cilium.io/global: "true"`, Cilium never treats this
   Service as a cross-cluster candidate, no matter how many clusters are
   meshed together.

## Fix

Add the global-service annotation (see `manifests/expected/catalog-service.yaml`
for the full corrected object):

```bash
kubectl -n ckne-atm-06 annotate service catalog service.cilium.io/global="true"
```

This also implicitly sets Cilium's default of
`service.cilium.io/shared: "true"` — meaning `catalog`'s own local backends
would, in a real mesh, be shared out to remote clusters too, not just used
to discover remote backends.

## Verify

```bash
kubectl -n ckne-atm-06 get svc catalog -o jsonpath='{.metadata.annotations}{"\n"}'
make validate LAB=ATM-06
```

## Why this lab stops here

With only one real cluster in this environment, there is no second
`clustermesh-apiserver` to connect to and no `cilium clustermesh connect`
step to run — so this lab cannot demonstrate a remote cluster actually
discovering `catalog`. What it does prove, honestly: the control-plane
component this discovery depends on is healthy, and the Service itself is
now correctly configured to participate the moment a real mesh exists.
