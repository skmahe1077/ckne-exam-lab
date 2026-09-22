# CKNE-CNI-01 — Solution

## Root cause

The `web` Deployment's Pod template carries `nodeSelector: {disktype: ssd}`, and no node in the cluster carries a `disktype=ssd` label — the scheduler can never place these Pods, so they stay `Pending` and Cilium (the CNI) is never even invoked. Cilium itself is healthy.

## Investigation process

Start with the cluster-wide picture before looking at the namespace:

```bash
kubectl -n kube-system get daemonset cilium
# DESIRED == READY on every node
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
```

Cilium is healthy cluster-wide. Then look at the Pods:

```bash
kubectl -n ckne-cni-01 get pods -o wide
```

The `web` Pods are `Pending`, not `ContainerCreating`/`CrashLoopBackOff` — a scheduling status, not a networking one. Ask Kubernetes why directly:

```bash
kubectl -n ckne-cni-01 describe pod -l app=web
```

The `Events` section shows something like:
```
Warning  FailedScheduling  ... 0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector.
```

```bash
kubectl -n ckne-cni-01 get deployment web -o yaml | grep -A2 nodeSelector
kubectl get nodes --show-labels
```

confirms no node carries `disktype=ssd`.

## Corrected configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ckne-cni-01
  labels:
    app: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

Equivalent inline patch (remove the `nodeSelector` entirely):

```bash
kubectl -n ckne-cni-01 patch deployment web --type=json \
  -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

## Verification steps

```bash
kubectl -n ckne-cni-01 rollout status deployment/web
kubectl -n ckne-cni-01 get pods -o wide
make validate LAB=CNI-01
```

## Why this works

The kubelet only asks the CNI plugin to network a Pod once the scheduler has already placed it on a node — if the scheduler can't place the Pod at all (a `nodeSelector`/affinity/taint mismatch, insufficient resources, and so on), the Pod stays `Pending` and CNI is never invoked. Removing the `nodeSelector` that referenced a label no node carries lets the scheduler place the Pods normally, at which point Cilium — already healthy the entire time — networks them without any change to the CNI installation itself. The correct diagnostic order is cluster-wide CNI health first, then whether the Pod is even scheduled, then Events for *why* if it's `Pending`, and only then — if the Pod is scheduled but stuck — does the investigation actually point back at the CNI layer.

## Faster exam-oriented method

`kubectl get pods -o wide` and check `STATUS` first — `Pending` (not `ContainerCreating`) is an instant signal this is a scheduling problem, not a CNI problem, and rules out reinstalling/restarting Cilium before you even read an Event. `kubectl describe pod` then names the exact constraint; removing it is a one-line patch.

## Common mistakes

- Jumping straight to "reinstall/restart Cilium" because Pods aren't Ready — wastes time and risks breaking a shared, cluster-wide component every other lab also depends on, when the actual fault is scheduling, not networking.
- Not distinguishing `Pending` from `ContainerCreating`/`CrashLoopBackOff` in `kubectl get pods -o wide` — only the latter two statuses mean the CNI plugin was ever actually invoked for this Pod.
- Guessing at the cause instead of reading `kubectl describe pod`'s `Events` section, which states the scheduler's exact reason in plain text.
- Adding a matching node label instead of removing the `nodeSelector` — works, but is a larger, less minimal change than removing the incorrect constraint the Deployment should never have had.

## Relevant documentation

- Kubernetes network plugins (CNI) — https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Assigning Pods to Nodes — https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- Cilium troubleshooting — https://docs.cilium.io/en/stable/operations/troubleshooting/
