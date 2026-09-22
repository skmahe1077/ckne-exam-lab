# CKNE-SEC-02 — Solution

## Root cause

`default-deny-egress` selects `app: client` with `policyTypes: [Egress]` and no `egress` rules — `client` cannot send any outbound traffic, including DNS queries to CoreDNS, so name resolution itself fails before connectivity to `allowed-svc` is even attempted.

## Investigation process

Confirm the starting state — even DNS is broken right now:

```bash
kubectl -n ckne-sec-02 get networkpolicy
kubectl -n ckne-sec-02 exec client -- nslookup allowed-svc
```

Look at what CoreDNS actually looks like in this cluster so you know what to select in the egress rule:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system get svc kube-dns
```

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-and-allowed-target
  namespace: ckne-sec-02
spec:
  podSelector:
    matchLabels:
      app: client
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
    - to:
        - podSelector:
            matchLabels:
              app: allowed-target
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-02/manifests/expected/allow-dns-and-allowed-target.yaml
```

`default-deny-egress` is left completely untouched.

## Verification steps

```bash
kubectl -n ckne-sec-02 exec client -- nslookup allowed-svc                              # resolves
kubectl -n ckne-sec-02 exec client -- wget -q -T 5 -O- http://allowed-svc               # succeeds
kubectl -n ckne-sec-02 exec client -- wget -q -T 5 -O- http://blocked-svc               # times out
make validate LAB=SEC-02
```

## Why this works

The moment any `NetworkPolicy` with `policyTypes: [Egress]` selects a Pod, that Pod's outbound traffic flips from "allow everything" to "deny everything except what an Egress rule explicitly allows" — and that includes DNS, since a Pod's own lookup of a Service's ClusterIP goes out over UDP/TCP port 53 to CoreDNS, itself traffic subject to the same policy. Without an explicit DNS allow rule, `client` can't resolve any name — not even ones in its own namespace — so an otherwise-correct "allow egress to `allowed-svc`" rule would still appear to fail, because `client` can't look up `allowed-svc`'s IP in the first place. Adding two egress rules (DNS to CoreDNS via `namespaceSelector`+`podSelector`, and TCP/80 to `allowed-target` specifically) on a new, additive policy restores exactly the two paths needed while `blocked-target`, having no matching allow rule, stays unreachable.

## Faster exam-oriented method

`kubectl exec client -- nslookup allowed-svc` failing immediately under a known `default-deny-egress` policy is the signature of the DNS trap — recognize it and write both rules (DNS + target) in one policy from the start, rather than debugging DNS and app connectivity as two separate investigations.

## Common mistakes

- Writing only the `allowed-target` egress rule and forgetting DNS — the most common mistake with default-deny-egress; without it, `client` can't resolve `allowed-svc`'s name at all, so even a correct app-traffic rule looks broken.
- Selecting CoreDNS by `podSelector` alone without a `namespaceSelector` for `kube-system` — NetworkPolicy `to`/`from` peer selectors don't cross namespaces implicitly; both selectors are needed together to target CoreDNS specifically.
- Allowing only TCP/53 or only UDP/53 for DNS — most resolvers use UDP first, but some queries (or resolvers configured that way) fall back to or use TCP; the reference fix allows both.
- Editing or removing `default-deny-egress` instead of adding a second policy — violates the requirement to leave it in place, and removes the deny-by-default posture for every other kind of traffic `client` shouldn't have.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Declare a NetworkPolicy — https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
