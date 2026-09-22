# CKNE-CNI-02 — Solution

## Root cause

`NetworkPolicy` `allow-server-ingress` allows ingress to `server` only from `ipBlock.cidr: 172.20.0.0/16`, but the cluster's actual Pod CIDR is `10.244.0.0/16` (the `podSubnet` set at cluster bootstrap). No Pod IP the CNI ever hands out falls inside `172.20.0.0/16`, so the rule can never match real traffic and everything to `server` is dropped.

## Investigation process

Both Deployments report Ready, so the Pods themselves are healthy — the problem is in what's allowed to reach `server`:

```bash
kubectl -n ckne-cni-02 get pods -o wide
kubectl -n ckne-cni-02 get networkpolicy allow-server-ingress -o yaml
```

The policy allows ingress only from `ipBlock.cidr: 172.20.0.0/16`. Real Pod IPs in this cluster (and every namespace) are drawn from `10.244.0.0/16` — confirm this against real, running Pods rather than assuming it:

```bash
kubectl -n ckne-cni-02 get pods -o wide
```

The `client` Pod's IP (and every other Pod IP) falls inside `10.244.0.0/16`, never inside `172.20.0.0/16`.

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-server-ingress
  namespace: ckne-cni-02
spec:
  podSelector:
    matchLabels:
      app: server
  policyTypes:
    - Ingress
  ingress:
    - from:
        - ipBlock:
            cidr: 10.244.0.0/16
      ports:
        - protocol: TCP
          port: 80
```

Equivalent inline patch:

```bash
kubectl -n ckne-cni-02 patch networkpolicy allow-server-ingress --type=json \
  -p '[{"op":"replace","path":"/spec/ingress/0/from/0/ipBlock/cidr","value":"10.244.0.0/16"}]'
```

## Verification steps

```bash
SERVER_IP=$(kubectl -n ckne-cni-02 get pods -l app=server -o jsonpath='{.items[0].status.podIP}')
CLIENT_POD=$(kubectl -n ckne-cni-02 get pods -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl -n ckne-cni-02 exec "$CLIENT_POD" -- wget -q -T 5 -O- "http://${SERVER_IP}:80"
make validate LAB=CNI-02
```

## Why this works

Every Pod IP in this cluster is structurally guaranteed to fall inside the cluster's Pod CIDR — Cilium's per-node IPAM claims a block of that range and hands out addresses from it, so no Pod will ever get an IP outside `10.244.0.0/16`. A `NetworkPolicy` `ipBlock` rule scoped to a CIDR that doesn't overlap that range can therefore never match any real Pod, no matter how correctly the rest of the policy (`podSelector`, `ports`) is written — the object applies cleanly and looks correct at a glance, with no error surfaced anywhere. Correcting `ipBlock.cidr` to the cluster's actual Pod CIDR is what lets the rule start matching real traffic from `client` (and any other Pod), while keeping ingress scoped to the cluster's own Pods rather than opening it to everything.

## Faster exam-oriented method

`kubectl get pods -o wide` to read one real Pod IP, then `kubectl get networkpolicy allow-server-ingress -o yaml` to read `ipBlock.cidr` — if the Pod IP doesn't fall inside that CIDR, that's the entire diagnosis. One JSON patch replacing the CIDR value fixes it.

## Common mistakes

- Deleting the NetworkPolicy instead of correcting it — removes the block but violates the requirement that it "still exists" and that ingress "must still scope to the cluster's actual Pod CIDR, not open it to everything."
- Widening the CIDR to `0.0.0.0/0` to "just make it work" — passes locally but abandons the policy's actual purpose of scoping ingress, and is explicitly disallowed by the requirements.
- Guessing the Pod CIDR from memory/documentation instead of confirming it against real, running Pod IPs — the CIDR is a per-cluster/per-installation value, and this lab specifically tests checking it rather than assuming it.
- Debugging the Deployments or Services for a networking issue when both are already Ready — the fault is entirely in the NetworkPolicy's `ipBlock`, not in workload health.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Cluster networking overview — https://kubernetes.io/docs/concepts/cluster-administration/networking/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
