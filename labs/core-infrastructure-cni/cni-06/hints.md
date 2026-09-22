# Hints — CNI-06

## Level 1

Look at what's already there before writing anything:

```bash
kubectl -n ckne-cni-06 get pods -o wide
kubectl -n ckne-cni-06 get svc
kubectl -n ckne-cni-06 get networkpolicy
```

Notice there is no `NetworkPolicy` yet — both `data-svc` and `mgmt-svc` are
wide open to any Pod right now.

## Level 2

Confirm the "one real interface" claim directly instead of assuming it:

```bash
kubectl -n ckne-cni-06 get pod -l app=multi-iface-app -o jsonpath='{.items[0].status.podIPs}'
```

Then check which client currently reaches which port:

```bash
kubectl -n ckne-cni-06 exec client       -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090
kubectl -n ckne-cni-06 exec admin-client -- wget -qT5 -O- http://mgmt-svc.ckne-cni-06.svc.cluster.local:9090
```

Both currently succeed — that's the problem to fix.

## Level 3

Write one `NetworkPolicy` selecting `app: multi-iface-app` with two ingress
rules: one for port 8080 with no `from` restriction at all (open to the
whole namespace), and a second for port 9090 restricted by
`podSelector: {matchLabels: {role: admin}}`. See
`manifests/expected/networkpolicy.yaml` for the exact shape.
