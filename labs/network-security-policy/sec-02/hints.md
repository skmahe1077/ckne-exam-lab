# Hints — SEC-02

## Level 1

Confirm the starting state — even DNS is broken right now:

```bash
kubectl -n ckne-sec-02 get networkpolicy
kubectl -n ckne-sec-02 exec client -- nslookup allowed-svc
```

## Level 2

Look at what CoreDNS actually looks like in this cluster so you know what to
select in your egress rule:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system get svc kube-dns
```

## Level 3

Write a new NetworkPolicy selecting `app: client` with `policyTypes:
[Egress]` and TWO egress entries: one `to` CoreDNS (`namespaceSelector`
matching `kube-system`, `podSelector` matching `k8s-app: kube-dns`, ports
UDP/53 and TCP/53), and one `to` a `podSelector` matching `app:
allowed-target` on TCP/80. Apply it, then re-run `make validate LAB=SEC-02`.
