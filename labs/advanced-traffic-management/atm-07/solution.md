# CKNE-ATM-07 — Solution

**Scope note:** this environment has only one real Kubernetes cluster, so this lab (and its solution below) only exercises control-plane readiness and the per-Service affinity configuration — it does not, and cannot, prove requests actually get distributed local-first. See `concept.md` for the full reasoning.

## Root cause

The `pricing` Service is already correctly marked `service.cilium.io/global: "true"` and `service.cilium.io/shared: "true"`, but its `service.cilium.io/affinity` annotation is set to `"remote"` — the opposite of the required "prefer local, fail over to remote only if local is unhealthy" policy.

## Investigation process

```bash
kubectl -n kube-system get deployment clustermesh-apiserver
```

Control-plane precondition is healthy. Then check the Service's current annotations:

```bash
kubectl -n ckne-atm-07 get svc pricing -o jsonpath='{.metadata.annotations}{"\n"}'
# service.cilium.io/global=true, service.cilium.io/shared=true, service.cilium.io/affinity=remote
```

`global` and `shared` are already correct; `affinity` is backwards from what's required.

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pricing
  namespace: ckne-atm-07
  labels:
    app: pricing
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
    service.cilium.io/affinity: "local"
spec:
  selector:
    app: pricing
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Equivalent inline command:

```bash
kubectl -n ckne-atm-07 annotate service pricing service.cilium.io/affinity="local" --overwrite
```

## Verification steps

```bash
kubectl -n ckne-atm-07 get svc pricing -o jsonpath='{.metadata.annotations}{"\n"}'
make validate LAB=ATM-07
```

In a real mesh, you'd also confirm effective behavior with `kubectl -n kube-system exec ds/cilium -- cilium-dbg service list --clustermesh-affinity`, which marks each backend `(preferred)` based on this annotation.

## Why this works

The `service.cilium.io/affinity` annotation takes three values: `none` (default, no preference — load-balance evenly across local and remote), `local` (prefer healthy local backends, fail over to remote only if every local backend is unhealthy), and `remote` (the inverse). With `affinity: remote`, Cilium would prefer the *other* cluster's backends and only use local ones as a fallback — exactly backwards from the required policy. Setting it to `local` is what expresses "keep traffic close unless we have to fail over." `global` and `shared` control *whether* a Service participates in cross-cluster load-balancing at all; `affinity` controls the *preference* once it does — two independent settings, which is why only one needed to change here.

## Faster exam-oriented method

`kubectl get svc pricing -o jsonpath='{.metadata.annotations}'` — read the three `service.cilium.io/*` values directly; `affinity=remote` against a "prefer local" requirement is the entire diagnosis. One `kubectl annotate --overwrite` fixes it.

## Common mistakes

- Changing `service.cilium.io/global` or `service.cilium.io/shared` while diagnosing — both are correct preconditions per the requirements; only `affinity` is wrong.
- Setting `affinity` to `none` instead of `local` — `none` removes preference entirely rather than expressing "prefer local, fail over to remote," which doesn't satisfy the stated policy.
- Modifying the `pricing` Deployment or its selector looking for the bug — it's already correct; the misconfiguration is entirely in the Service's annotations.
- Expecting this lab's verification to prove traffic actually lands local-first — with only one cluster in this environment, that's out of scope by design; the check is that the Service is correctly configured to apply that policy the moment a real mesh exists.

## Relevant documentation

- Cilium Cluster Mesh affinity — https://docs.cilium.io/en/stable/network/clustermesh/affinity/
- Cilium Cluster Mesh load-balancing — https://docs.cilium.io/en/stable/network/clustermesh/load-balancing/
- Cilium Cluster Mesh setup — https://docs.cilium.io/en/stable/network/clustermesh/setup/
- Helm upgrade reference — https://helm.sh/docs/helm/helm_upgrade/
