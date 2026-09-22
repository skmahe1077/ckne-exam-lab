# Hints — SEC-07

## Level 1

```bash
kubectl -n ckne-sec-07 get networkpolicy
kubectl -n ckne-sec-07 exec deploy/client -- nslookup kubernetes.default.svc.cluster.local
```

DNS fails because `deny-all-egress` blocks everything, including the
lookup to CoreDNS. Don't touch that policy — add a second one.

## Level 2

NetworkPolicies for the same Pods are additive. Find CoreDNS's actual pod
labels and namespace:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns --show-labels
kubectl get namespace kube-system --show-labels
```

## Level 3

Add a NetworkPolicy in `ckne-sec-07` with an egress rule `to` a peer
combining `namespaceSelector: {kubernetes.io/metadata.name: kube-system}`
and `podSelector: {k8s-app: kube-dns}`, ports UDP/53 and TCP/53 — see
`manifests/expected/networkpolicy.yaml`.
