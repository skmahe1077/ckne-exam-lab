# CKNE-CNI-05 — Solution

## Root cause

`client`'s Pod spec sets `dnsPolicy: None` with a `dnsConfig.nameservers` pointing at `192.0.2.53` — a TEST-NET-1 address (RFC 5737) that never answers. This completely bypasses CoreDNS for this Pod only; CoreDNS itself and every other Pod in the cluster are unaffected.

## Investigation process

Rule cluster-wide DNS in or out first:

```bash
kubectl -n kube-system get deployment coredns
# READY == desired replicas
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

CoreDNS is healthy cluster-wide — the problem must be specific to `client`. Confirm the symptom directly:

```bash
kubectl -n ckne-cni-05 exec client -- nslookup server.ckne-cni-05.svc.cluster.local
```

Inspect how `client` is configured for DNS:

```bash
kubectl -n ckne-cni-05 get pod client -o yaml | grep -A5 dnsPolicy
kubectl -n ckne-cni-05 exec client -- cat /etc/resolv.conf
```

`dnsPolicy: None` with `dnsConfig.nameservers: [192.0.2.53]`. Compare against a Pod that resolves fine:

```bash
SERVER_POD=$(kubectl -n ckne-cni-05 get pods -l app=server -o jsonpath='{.items[0].metadata.name}')
kubectl -n ckne-cni-05 exec "$SERVER_POD" -- cat /etc/resolv.conf
```

`server`'s Pod uses the default cluster resolver; `client`'s is overridden entirely.

## Corrected configuration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ckne-cni-05
  labels:
    app: client
spec:
  containers:
    - name: client
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 25m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
```

`dnsPolicy`/`dnsConfig` are immutable once a Pod is created, so the Pod must be recreated without the override:

```bash
kubectl -n ckne-cni-05 delete pod client
kubectl -n ckne-cni-05 run client --image=busybox:1.36 --restart=Never \
  --command -- sh -c "sleep 3600"
```

## Verification steps

```bash
kubectl -n ckne-cni-05 exec client -- nslookup server.ckne-cni-05.svc.cluster.local
kubectl -n ckne-cni-05 exec client -- wget -q -T5 -O- http://server.ckne-cni-05.svc.cluster.local
make validate LAB=CNI-05
```

## Why this works

DNS resolution has two independent layers: cluster-level (CoreDNS, shared by every Pod) and Pod-level (`dnsPolicy`/`dnsConfig`, set per-Pod). A Pod's own `/etc/resolv.conf` is controlled entirely by these two fields — `dnsPolicy: None` hands control completely to `dnsConfig`, using *only* what's specified there instead of the cluster default, with nothing else supplied. This is why a single Pod can have completely broken DNS, pointed at an unreachable nameserver, while CoreDNS and every other Pod in the cluster are entirely unaffected. Removing the override lets the Pod fall back to the Kubernetes default (`ClusterFirst`), which resolves in-cluster Service names via CoreDNS exactly like `server`'s Pod already does — the fix never touches CoreDNS or anything in `kube-system`.

## Faster exam-oriented method

`kubectl get deployment coredns -n kube-system` for a one-line cluster-wide health check, then straight to `kubectl get pod client -o yaml | grep -A5 dnsPolicy` — `dnsPolicy: None` with an unfamiliar `nameservers` IP is the entire diagnosis. Delete and recreate the Pod without the override.

## Common mistakes

- Jumping to restart or reconfigure CoreDNS/`kube-system` before checking whether the issue is cluster-wide — wastes time and risks touching a shared resource every other lab also depends on, when only one Pod is actually affected.
- Trying to `kubectl edit`/`kubectl patch` the running Pod's `dnsPolicy` or `dnsConfig` in place — these fields are immutable on an existing Pod; the object must be deleted and recreated.
- Assuming a DNS failure always means CoreDNS is broken, without first comparing `/etc/resolv.conf` between the failing Pod and a working sibling Pod in the same namespace — the fastest way to see a Pod-level override is a side-by-side comparison, not staring at the failing Pod alone.
- Overcorrecting by adding a new `dnsConfig` with a "known-good" nameserver instead of simply removing the override — the minimum fix is deleting `dnsPolicy: None`/`dnsConfig` entirely so the Pod inherits the cluster default, not replacing one custom config with another.

## Relevant documentation

- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Custom DNS configuration — https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
- Debugging Services — https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
