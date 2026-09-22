# Hints — CNI-03

## Level 1

`toolbox` is Running and Ready — this isn't a scheduling problem. Start by
ruling routing in or out:

```bash
kubectl -n ckne-cni-03 exec toolbox -- ip addr
kubectl -n ckne-cni-03 exec toolbox -- ip route
```

Does the interface have an address in the expected Pod CIDR range? Is
there a sane default route?

## Level 2

If routing looks normal, the next place packets get evaluated before
leaving the Pod is its own `iptables` `OUTPUT` chain:

```bash
kubectl -n ckne-cni-03 exec toolbox -- iptables -L OUTPUT -n -v --line-numbers
```

Look at the `target` column for each rule and the `dpt:` match in
`destination`. One rule's counters (`pkts`/`bytes`) should be incrementing
every time you attempt a connection to port 80 — that's your culprit.

## Level 3

Delete only the offending rule from `toolbox`'s own `OUTPUT` chain — you
can target it either by full rule specification or by the line number you
saw in Level 2 (`iptables -D OUTPUT <line-number>`). Don't flush the whole
chain, and don't touch any other Pod or the node. After deleting it,
re-test:

```bash
kubectl -n ckne-cni-03 exec toolbox -- curl -s -o /dev/null -w '%{http_code}\n' http://server.ckne-cni-03.svc.cluster.local
```
