# Solution — ATM-07

## Diagnosis

1. The control-plane precondition is already satisfied:

   ```bash
   kubectl -n kube-system get deployment clustermesh-apiserver
   ```

2. `pricing`'s annotations show it is already global and shared, but its
   affinity is the opposite of what's required:

   ```bash
   kubectl -n ckne-atm-07 get svc pricing -o jsonpath='{.metadata.annotations}{"\n"}'
   # service.cilium.io/global=true, service.cilium.io/shared=true, service.cilium.io/affinity=remote
   ```

   With `affinity: remote`, Cilium would prefer the *other* cluster's
   backends and only use local ones as a fallback — backwards from the
   required "prefer local, fail over to remote" policy.

## Fix

Correct the affinity annotation (see
`manifests/expected/pricing-service.yaml` for the full corrected object):

```bash
kubectl -n ckne-atm-07 annotate service pricing service.cilium.io/affinity="local" --overwrite
```

`global` and `shared` were already correct and don't need to change.

## Verify

```bash
kubectl -n ckne-atm-07 get svc pricing -o jsonpath='{.metadata.annotations}{"\n"}'
make validate LAB=ATM-07
```

## Why this lab stops here

With only one real cluster in this environment, there are no remote-cluster
backends to actually observe traffic landing on, so this lab cannot
demonstrate local-first distribution happening live — that would require a
second real cluster connected via `cilium clustermesh connect`. What it does
prove, honestly: the control-plane component this depends on is healthy, and
`pricing` is now correctly configured to apply the required local-first
policy the moment a real mesh exists. In a real mesh, you'd confirm the
effective behavior with
`kubectl -n kube-system exec ds/cilium -- cilium-dbg service list --clustermesh-affinity`,
which marks each backend `(preferred)` based on this exact annotation.
