# CKNE-CNI-03 — Solution

## Root cause

An `initContainer` (`break-network`) ran once at `toolbox`'s startup and added an explicit `iptables -A OUTPUT -p tcp --dport 80 -j DROP` rule to `toolbox`'s own network namespace. Routing inside the Pod is otherwise normal — this is entirely local to `toolbox`'s own netns, unrelated to Cilium, the node, or the `server` Pod.

## Investigation process

Routing inside `toolbox` is normal — rule this out first:

```bash
kubectl -n ckne-cni-03 exec toolbox -- ip addr
kubectl -n ckne-cni-03 exec toolbox -- ip route
# eth0 has an address in 10.244.0.0/16, default route via the Pod's gateway
```

Then inspect `toolbox`'s own `OUTPUT` chain:

```bash
kubectl -n ckne-cni-03 exec toolbox -- iptables -L OUTPUT -n -v --line-numbers
# ... DROP  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:80
```

That rule's packet counter increments on every connection attempt to port 80 — the culprit.

## Corrected configuration

The fix is imperative, applied at runtime against the running Pod's netns — not a manifest change (`manifests/expected/toolbox.yaml` shows what the Pod spec would look like if the `break-network` initContainer had never existed, for reference only):

```bash
kubectl -n ckne-cni-03 exec toolbox -- iptables -D OUTPUT -p tcp --dport 80 -j DROP
```

Delete by exact rule spec (as above) or by the line number seen in the investigation step (`iptables -D OUTPUT <line-number>`) — either targets only that one rule.

## Verification steps

```bash
kubectl -n ckne-cni-03 exec toolbox -- iptables -L OUTPUT -n -v
kubectl -n ckne-cni-03 exec toolbox -- curl -s -o /dev/null -w '%{http_code}\n' \
  http://server.ckne-cni-03.svc.cluster.local
make validate LAB=CNI-03
```

## Why this works

Cilium programs its own eBPF datapath at the node level to route and secure traffic between Pods, but that's a separate layer from what happens inside an individual Pod's own network namespace — with `NET_ADMIN`/`NET_RAW` capabilities and `iptables` tooling present, a container has its own independent set of iptables chains, completely isolated from the node's and every other Pod's. `toolbox`'s `OUTPUT` chain matching and dropping its own outbound tcp/80 traffic is exactly this: a container breaking its own networking with nothing wrong with Cilium, the node, or the `server` Pod. Deleting just that one rule (rather than flushing the whole chain) restores outbound tcp/80 without touching anything else in `toolbox`'s ruleset, and without touching any state outside this one Pod's netns.

## Faster exam-oriented method

Skip straight to `iptables -L OUTPUT -n -v --line-numbers` inside the Pod once routing looks sane — the first matching rule with non-zero packet counters against `dpt:80` is the answer. `iptables -D OUTPUT -p tcp --dport 80 -j DROP` removes it in one command.

## Common mistakes

- Flushing the entire `OUTPUT` chain (`iptables -F OUTPUT`) instead of deleting only the offending rule — works but violates the "minimum change necessary" requirement and could remove other legitimate rules in a less contrived scenario.
- Looking at node-level iptables or Cilium's eBPF state instead of the Pod's own netns — this Pod-local `DROP` rule is invisible at the node level entirely; it only exists inside `toolbox`'s own network namespace.
- Skipping the `ip addr`/`ip route` check and jumping straight to iptables — usually fine here since routing is in fact normal, but the diagnostic order (routing before iptables) matters in general because a route problem means packets never reach the interface correctly in the first place.
- Trying to fix this by modifying the Pod manifest and reapplying — the bad rule was injected imperatively by an initContainer that already ran; reapplying the same broken manifest won't remove an existing rule, and the running Pod's netns must be fixed directly with `iptables -D`.

## Relevant documentation

- Debugging with network utility Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
- netfilter/iptables documentation — https://www.netfilter.org/documentation/
