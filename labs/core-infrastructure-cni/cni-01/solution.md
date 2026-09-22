# Solution — CNI-01

## Diagnosis

1. Cilium is healthy cluster-wide:

   ```bash
   kubectl -n kube-system get daemonset cilium
   # DESIRED == READY on every node
   ```

2. The `web` Pods are `Pending`, not `ContainerCreating`/`CrashLoopBackOff`
   — meaning the scheduler never placed them, so the CNI plugin was never
   even invoked:

   ```bash
   kubectl -n ckne-cni-01 get pods -o wide
   ```

3. `kubectl -n ckne-cni-01 describe pod -l app=web` shows an Event like:

   ```
   Warning  FailedScheduling  ... 0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector.
   ```

4. The Deployment's Pod template has `nodeSelector: {disktype: ssd}`, and no
   node in the cluster carries a `disktype=ssd` label
   (`kubectl get nodes --show-labels`).

## Fix

Remove the `nodeSelector` (see `manifests/expected/deployment.yaml` for the
full corrected object):

```bash
kubectl -n ckne-cni-01 patch deployment web --type=json \
  -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

## Verify

```bash
kubectl -n ckne-cni-01 rollout status deployment/web
kubectl -n ckne-cni-01 get pods -o wide
make validate LAB=CNI-01
```

Cilium was never the problem — the exercise is precisely that a symptom
("Pods not Ready") does not automatically implicate the CNI layer.
