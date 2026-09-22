# Concept: Hubble Flows for Network Visibility

Cilium's datapath runs in eBPF, attached directly to each node's network
interfaces. Every packet it forwards or drops is a decision Cilium already
made — the question for a human troubleshooting a connectivity problem is
just "can I see that decision?" **Hubble** is Cilium's observability layer:
each `cilium` agent Pod keeps a local, bounded ring buffer of every flow it
has observed on its node, and a cluster-wide `hubble-relay` Deployment can
aggregate those per-node buffers into one queryable stream.

A **flow** is Hubble's unit of observation — roughly "one packet or
connection, annotated with everything Cilium knows about it": source/destination
Pod and namespace, L4 protocol and port, and a **verdict**:

- `FORWARDED` — the packet was allowed and sent on.
- `DROPPED` — the packet was rejected, with a reason (e.g. `Policy denied`
  for a NetworkPolicy/CiliumNetworkPolicy deny, or other datapath reasons
  like no route).
- `ERROR` — the flow processing itself hit an error.

This matters because a *denied* connection is not an absence of signal — it
is a **positive, queryable event**. When `kubectl exec` from a client Pod
times out, that alone doesn't tell you whether the Service doesn't exist,
DNS failed, or a NetworkPolicy is enforcing a deny. Hubble answers that
directly: a `DROPPED ... Policy denied` flow proves the packet reached
Cilium's datapath and was intentionally rejected by policy — not lost to
routing, not a DNS failure, not a crashed backend.

**Querying Hubble without the relay.** The `hubble` CLI ships inside every
`cilium` agent Pod and, by default, talks to that agent's own local Unix
socket — no separate install and no need for `hubble-relay` for basic
per-node queries:

```bash
kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace <ns> --last 100
```

The catch: this only shows flows **that specific node's agent observed**.
A flow between two Pods on different nodes is usually visible from both the
sending node's agent (as egress) and the receiving node's agent (as
ingress), but if you only check one agent Pod and it's the "wrong" node,
you may see nothing. `hubble-relay` exists specifically to remove this
per-node blind spot by fanning a single query out to every agent and
merging the results — but for a single, targeted diagnostic query, checking
each agent Pod directly (there are only as many as there are nodes) is
often faster than setting up a relay-aware client.
