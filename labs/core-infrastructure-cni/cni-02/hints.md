# Hints — CNI-02

## Level 1

Both Deployments are Ready, so this isn't a scheduling or image problem —
look at what sits between `client` and `server`:

```bash
kubectl -n ckne-cni-02 get pods -o wide
kubectl -n ckne-cni-02 get networkpolicy
```

What does `allow-server-ingress` restrict ingress to?

## Level 2

Compare the NetworkPolicy's allowed source range against the IPs Pods in
this cluster are actually getting:

```bash
kubectl -n ckne-cni-02 get networkpolicy allow-server-ingress -o yaml
kubectl -n ckne-cni-02 get pods -o wide
```

Does the `client` Pod's IP fall inside the `ipBlock.cidr` the policy
allows? If not, no traffic from `client` (or any other Pod) can ever match
that rule.

## Level 3

The cluster's Pod CIDR is fixed at install time (`podSubnet` in
`kubeadm.config`) and is the range every Pod IP is drawn from — you already
confirmed it in Level 2 by looking at real Pod IPs. Edit the
NetworkPolicy's `spec.ingress[0].from[0].ipBlock.cidr` so it matches that
real range instead of the value it currently has, keeping the policy
scoped to the Pod CIDR (not `0.0.0.0/0`).
