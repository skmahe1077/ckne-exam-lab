# Hints — SVC-07

## Level 1

Confirm kube-proxy's mode and health first:

```bash
kubectl -n kube-system get daemonset kube-proxy
kubectl -n kube-system get configmap kube-proxy -o yaml | grep -A2 "mode:"
```

Then look at what already exists in your namespace:

```bash
kubectl -n ckne-svc-07 get deployment,pods -o wide
kubectl -n ckne-svc-07 get service
```

There's a Deployment but no Service yet — that's the first thing to
create.

## Level 2

A normal Pod cannot see kube-proxy's rules — they live in the node's root
network namespace, not the Pod's own. To look at them, a debug Pod needs
to actually join the node's network namespace:

```bash
kubectl run <name> -n ckne-svc-07 --image=<image-with-iptables> --restart=Never --rm -i \
  --overrides='{"spec":{"hostNetwork":true,"containers":[{...,"securityContext":{"capabilities":{"add":["NET_ADMIN","NET_RAW"]}}}]}}' \
  -- <command>
```

Once you can run `iptables-save` from inside such a Pod, look for a chain
named `KUBE-SERVICES` and follow the jump for your Service's ClusterIP.

## Level 3

Get your Service's ClusterIP first:

```bash
kubectl -n ckne-svc-07 get service web -o jsonpath='{.spec.clusterIP}'
```

Then, from your `hostNetwork` + `NET_ADMIN`/`NET_RAW` debug Pod, run
`iptables-save` and search its output for that exact IP — you should find
it inside a `-d <ClusterIP>/32` match, on the chain kube-proxy generated
for the Service (`KUBE-SVC-...`), which jumps into one `KUBE-SEP-...`
chain per ready endpoint. If nothing matches, re-check the Service's
selector and port against the Deployment's Pod labels and container port.
