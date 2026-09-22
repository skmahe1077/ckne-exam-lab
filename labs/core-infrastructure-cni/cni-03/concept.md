# Concept: Linux Routing and iptables Inside a Pod's Network Namespace

Cilium programs its own datapath (eBPF, not traditional iptables) at the
node level to route and secure traffic between Pods — but that is a
separate layer from what happens *inside* an individual Pod's own network
namespace. Every container still runs on top of ordinary Linux networking
primitives: it has a routing table (`ip route`) and, if the `iptables`
tooling and `NET_ADMIN`/`NET_RAW` capabilities are present, its own
independent set of `iptables` chains (`ip netns` isolates this completely
from the node's and from every other Pod's).

This means a container can break its *own* networking without anything
being wrong with Cilium, the node, or any other Pod:

- An `ip route` entry that blackholes or misdirects traffic to a
  destination.
- An `iptables` rule in `OUTPUT` (outbound from this container) or `INPUT`
  (inbound to this container) that drops or rejects matching traffic.

Both are entirely local to that one Pod's netns. Diagnosing them requires
the same tools you'd use on a bare Linux host, just run via `kubectl exec`
against the Pod in question:

- `ip addr` / `ip route` — confirm the interface and routing table look as
  expected (default route present, correct subnet).
- `iptables -L -n -v --line-numbers` — list rules with hit counters, which
  chain, and in what order; the first matching rule wins.

The diagnostic order matters: check routing first (a route problem means
packets never even reach the interface correctly), then iptables (rules
that match and act on packets that *did* route correctly). A container
image bundling networking tools without ever exercising `NET_ADMIN`
capability is common in test/debug images like `nicolaka/netshoot` — this
is precisely the kind of Pod you reach for when you need to run these
diagnostics without SSH access to the underlying node.
