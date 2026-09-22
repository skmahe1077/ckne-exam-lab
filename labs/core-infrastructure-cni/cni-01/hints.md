# Hints — CNI-01

## Level 1

Start with the cluster-wide picture before looking at your namespace:

```bash
kubectl -n kube-system get daemonset cilium
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
```

Then look at your Pods:

```bash
kubectl -n ckne-cni-01 get pods -o wide
```

What `STATUS` are the `web` Pods in? Is that a networking status, or a
scheduling status?

## Level 2

Ask Kubernetes *why* directly instead of guessing:

```bash
kubectl -n ckne-cni-01 describe pod -l app=web
```

Read the `Events` section at the bottom. The scheduler logs the exact reason
it could not place the Pod on any node.

## Level 3

```bash
kubectl -n ckne-cni-01 get deployment web -o yaml | grep -A2 nodeSelector
kubectl get nodes --show-labels
```

Compare the two outputs. Nothing about Cilium needs to change — only the
Deployment's Pod spec.
