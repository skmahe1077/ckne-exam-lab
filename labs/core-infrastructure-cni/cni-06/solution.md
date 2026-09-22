# CKNE-CNI-06 — Solution

## Root cause

There is no `NetworkPolicy` at all in `ckne-cni-06`, so both `client` and `admin-client` can currently reach both `data-svc` (8080) and `mgmt-svc` (9090) — the management plane is not actually restricted to admins. This is an absence-of-policy task, not a broken-object bug.

## Investigation process

Look at what's already there before writing anything:

```bash
kubectl -n ckne-cni-06 get pods -o wide
kubectl -n ckne-cni-06 get svc
kubectl -n ckne-cni-06 get networkpolicy
```

No `NetworkPolicy` exists yet. Confirm the "one real interface" claim directly instead of assuming it:

```bash
kubectl -n ckne-cni-06 get pod -l app=multi-iface-app -o jsonpath='{.items[0].status.podIPs}'
```

Exactly one entry — one real network interface, despite `multi-iface-app` serving two logical "interfaces" via its two containers/ports. Then confirm the current (over-permissive) reachability:

```bash
kubectl -n ckne-cni-06 exec client       -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090
kubectl -n ckne-cni-06 exec admin-client -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090
```

Both currently succeed — that's the problem to fix.

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-iface-per-port
  namespace: ckne-cni-06
spec:
  podSelector:
    matchLabels:
      app: multi-iface-app
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - protocol: TCP
          port: 8080
    - from:
        - podSelector:
            matchLabels:
              role: admin
      ports:
        - protocol: TCP
          port: 9090
```

```bash
kubectl apply -f labs/core-infrastructure-cni/cni-06/manifests/expected/networkpolicy.yaml
```

## Verification steps

```bash
kubectl -n ckne-cni-06 exec client       -- wget -qT5 -O- http://data-svc.ckne-cni-06.svc.cluster.local:8080   # succeeds
kubectl -n ckne-cni-06 exec client       -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090   # times out
kubectl -n ckne-cni-06 exec admin-client -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090   # succeeds
make validate LAB=CNI-06
```

## Why this works

Multus (not installed in this cluster) would normally give each traffic plane its own real NIC and its own independent security boundary. Without it, a single `NetworkPolicy` with per-port ingress rules approximates the same security intent using the primitives that do exist: the first ingress rule has no `from` at all, so it allows traffic from any source in the namespace on port 8080 only; the second rule adds a `podSelector: {role: admin}` restriction and applies only to port 9090. Because both rules select the same Pod (`app: multi-iface-app`) but scope to different ports, each simulated "interface" ends up with its own independent reachability rule — the data plane stays open to the namespace, the management plane is restricted to admins — even though both ports are served from the one real interface confirmed by `status.podIPs`.

## Faster exam-oriented method

`kubectl get networkpolicy -n ckne-cni-06` — empty, meaning "add one" is the entire task, no debugging required. Write the two-rule policy directly (one port-only rule for 8080, one port+podSelector rule for 9090) and apply it.

## Common mistakes

- Splitting the two ports across two separate `NetworkPolicy` objects instead of two `ingress` rules on one policy — works functionally but isn't necessary and adds objects beyond what the task calls for.
- Putting a `podSelector` restriction on the port 8080 rule "for consistency" — this breaks the requirement that the data plane stay reachable from any Pod in the namespace.
- Reaching for Multus objects (`NetworkAttachmentDefinition`, `k8s.v1.cni.cncf.io/networks`) — explicitly out of scope; Multus isn't installed in this cluster and the task must be solved entirely with a `NetworkPolicy`.
- Assuming the Pod has two network interfaces because it has two containers on two ports, without actually checking `status.podIPs` — the task specifically requires confirming there's only one real interface rather than assuming it from the container count.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy to/from selector behavior — https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors
- Pods with multiple containers — https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers
- Network plugins (CNI) — https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
