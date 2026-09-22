# Hints — SEC-06

## Level 1

Look at what already exists before writing anything:

```bash
kubectl -n ckne-sec-06 get configmap node-cidrs -o yaml
kubectl -n ckne-sec-06 get networkpolicy restrict-backend-ingress -o yaml
kubectl -n ckne-sec-06 get pod client-a client-b -o wide
```

Which of `client-a` / `client-b` can currently reach `backend`? Try both:

```bash
kubectl -n ckne-sec-06 exec client-a -- wget -q -T5 -O- http://backend
kubectl -n ckne-sec-06 exec client-b -- wget -q -T5 -O- http://backend
```

## Level 2

The `node-cidrs` ConfigMap has four keys: `node-a`, `node-a-cidr`, `node-b`,
`node-b-cidr`. `client-b` was scheduled onto the node named in `node-b`
(check with `kubectl -n ckne-sec-06 get pod client-b -o wide`), and its Pod
IP falls inside `node-b-cidr`.

The current policy's single `ipBlock` entry only has a `cidr` key — no
`except`. `except` entries live inside the same `ipBlock` block as `cidr`,
as a list.

## Level 3

```bash
kubectl -n ckne-sec-06 get configmap node-cidrs -o jsonpath='{.data.node-b-cidr}'
kubectl -n ckne-sec-06 edit networkpolicy restrict-backend-ingress
```

Add an `except:` list under the existing `ipBlock:` entry (same indentation
level as `cidr:`) containing exactly the `node-b-cidr` value you looked up —
do not change `cidr` itself, and do not add a second `ipBlock` item.
