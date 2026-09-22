# CKNE-ATM-06 — Solution

**Scope note:** this environment has only one real Kubernetes cluster, so this lab (and its solution below) only exercises the control-plane readiness and per-Service opt-in configuration for Cluster Mesh — it does not, and cannot, prove actual cross-cluster discovery. See `concept.md` for the full reasoning.

## Root cause

The `catalog` Service is missing the `service.cilium.io/global: "true"` annotation. Without it, Cilium never treats `catalog` as a cross-cluster discovery candidate, no matter how many clusters are meshed together — the Service works fine locally, but is invisible to Cluster Mesh.

## Investigation process

Confirm the control-plane precondition is genuinely satisfied first — not just that the Deployment exists, but that its TLS material is real:

```bash
kubectl -n kube-system get deployment clustermesh-apiserver
kubectl -n kube-system get secret clustermesh-apiserver-server-cert -o jsonpath='{.data}' | tr ',' '\n'
```

You should see non-empty `tls.crt`, `tls.key`, and `ca.crt` keys. Then check the Service itself:

```bash
kubectl -n ckne-atm-06 get svc catalog -o jsonpath='{.metadata.annotations}{"\n"}'
```

`catalog`'s Deployment is Ready and its Service routes traffic normally within this cluster, but its annotations don't mention `service.cilium.io` at all.

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: ckne-atm-06
  labels:
    app: catalog
  annotations:
    service.cilium.io/global: "true"
spec:
  selector:
    app: catalog
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Equivalent inline command:

```bash
kubectl -n ckne-atm-06 annotate service catalog service.cilium.io/global="true"
```

## Verification steps

```bash
kubectl -n ckne-atm-06 get svc catalog -o jsonpath='{.metadata.annotations}{"\n"}'
make validate LAB=ATM-06
```

## Why this works

Once clusters are meshed, cross-cluster service discovery is opt-in per Service via the `service.cilium.io/global: "true"` annotation — a Service without it behaves exactly as it always did, purely local to its own cluster. Adding the annotation is what tells Cilium "this Service is meant to be discovered and load-balanced across the whole mesh," and it also implicitly sets Cilium's default `service.cilium.io/shared: "true"`, meaning `catalog`'s own local backends would, in a real mesh, be shared out to remote clusters too, not just used to discover remote backends. Nothing about the Deployment, the selector, or `clustermesh-apiserver` itself needed to change — the control-plane component was already healthy; the Service simply hadn't opted in.

## Faster exam-oriented method

`kubectl get svc catalog -o jsonpath='{.metadata.annotations}'` — an empty or `service.cilium.io`-free result is the entire diagnosis. One `kubectl annotate` command fixes it; re-run the same jsonpath to confirm.

## Common mistakes

- Modifying the `catalog` Deployment (its selector, labels, or replicas) looking for the bug — it's already correct; the gap is purely a missing Service annotation.
- Editing `clustermesh-apiserver` or its Secrets while diagnosing — they're a healthy precondition, not the fault.
- Expecting this lab's verification to prove real cross-cluster discovery — with only one cluster in this environment, that's out of scope by design; the check is that the Service is correctly configured to participate the moment a real mesh exists.
- Forgetting that annotating with `service.cilium.io/global` alone also sets `shared: true` by default — worth knowing conceptually even though no extra action is needed here.

## Relevant documentation

- Cilium Cluster Mesh setup — https://docs.cilium.io/en/stable/network/clustermesh/setup/
- Cilium Cluster Mesh load-balancing — https://docs.cilium.io/en/stable/network/clustermesh/load-balancing/
- Helm upgrade reference — https://helm.sh/docs/helm/helm_upgrade/
