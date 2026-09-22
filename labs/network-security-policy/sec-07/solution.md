# CKNE-SEC-07 — Solution

## Root cause

`deny-all-egress` (`podSelector: {}`, `policyTypes: [Egress]`, empty `egress: []`) blocks all outbound traffic from `client`, including DNS lookups to CoreDNS. It must stay in place — the fix is an additive policy carving out DNS specifically, not an edit to the deny policy.

## Investigation process

```bash
kubectl -n ckne-sec-07 get networkpolicy
kubectl -n ckne-sec-07 exec deploy/client -- nslookup kubernetes.default.svc.cluster.local
```

DNS fails because `deny-all-egress` blocks everything, including the lookup to CoreDNS. Find CoreDNS's actual Pod labels and namespace:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns --show-labels
kubectl get namespace kube-system --show-labels
```

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: ckne-sec-07
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

```bash
kubectl apply -f labs/network-security-policy/sec-07/manifests/expected/networkpolicy.yaml
```

## Verification steps

```bash
kubectl -n ckne-sec-07 exec deploy/client -- nslookup kubernetes.default.svc.cluster.local   # succeeds
kubectl -n ckne-sec-07 exec deploy/client -- sh -c 'timeout 3 nc -zv 1.1.1.1 443'             # fails/times out
make validate LAB=SEC-07
```

Only DNS traffic to `kube-dns` is carved out — every other destination stays blocked by `deny-all-egress`.

## Why this works

`NetworkPolicy` objects selecting the same Pods are additive — Kubernetes evaluates each Pod's applicable egress rules as the union of every policy that selects it, rather than merging or overriding them. This means the correct way to carve an exception out of a broad deny-all policy is to add a second, narrower policy alongside it, keeping the deny-everything baseline auditable and unmodified. The DNS carve-out needs both a `namespaceSelector` (to reach into `kube-system`, a different namespace than `client`) and a `podSelector` (to target only `kube-dns` Pods within it) combined on the same `to` peer, plus both UDP and TCP port 53 since resolvers fall back to TCP for responses too large for a single UDP datagram. Because `deny-all-egress` still selects every Pod and allows nothing on its own, and `allow-dns-egress` allows exactly one narrow path, the union is "deny everything except DNS to CoreDNS" — external destinations on any port remain blocked.

## Faster exam-oriented method

Recognize the shape immediately: `deny-all-egress` with empty `egress: []` under a DNS-failure symptom is the canonical "forgot to carve out DNS" pattern. Write the second policy directly with both selectors combined and both ports, without needing to separately diagnose beyond confirming the deny policy exists.

## Common mistakes

- Editing `deny-all-egress` directly to add an exception — violates the requirement to leave it untouched, and mixes the security baseline with narrow application exceptions in one object.
- Allowing only UDP/53 and omitting TCP/53 — most DNS traffic is UDP, but larger responses and some resolver behavior fall back to TCP; omitting it can cause intermittent resolution failures under the exact conditions a real audit would probe.
- Scoping the DNS-allow rule too broadly (e.g. allowing all of `kube-system` rather than just `k8s-app: kube-dns` Pods, or omitting the port restriction) — passes the DNS check but also reopens egress to unrelated `kube-system` workloads or ports, failing the "every other form of outbound traffic must remain blocked" requirement.
- Using a custom namespace label instead of the standard immutable `kubernetes.io/metadata.name: kube-system` — the task specifically calls for the auto-applied label rather than one you'd have to add yourself.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Declare a NetworkPolicy — https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
