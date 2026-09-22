# Hints — CNI-05

## Level 1

Rule cluster-wide DNS in or out first:

```bash
kubectl -n kube-system get deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

If CoreDNS is fully Ready, the problem is specific to something in your
namespace. Then look at the symptom directly:

```bash
kubectl -n ckne-cni-05 exec client -- nslookup server.ckne-cni-05.svc.cluster.local
```

## Level 2

Compare how `client` is configured for DNS against a normal Pod:

```bash
kubectl -n ckne-cni-05 get pod client -o yaml | grep -A5 dnsPolicy
kubectl -n ckne-cni-05 exec client -- cat /etc/resolv.conf
```

Now look at a Pod that resolves fine, for contrast:

```bash
SERVER_POD=$(kubectl -n ckne-cni-05 get pods -l app=server -o jsonpath='{.items[0].metadata.name}')
kubectl -n ckne-cni-05 exec "$SERVER_POD" -- cat /etc/resolv.conf
```

What's different?

## Level 3

`client`'s Pod spec sets `dnsPolicy: None` with a custom `dnsConfig` that
overrides the normal cluster resolver entirely. Since nothing about this
Pod actually requires custom DNS behaviour, the minimum fix is to remove
the `dnsPolicy`/`dnsConfig` override so the Pod falls back to the
Kubernetes default (`ClusterFirst`) — the same behaviour `server` already
has. A Pod's `dnsPolicy`/`dnsConfig` can only be changed by recreating the
Pod (these fields aren't mutable in place).
