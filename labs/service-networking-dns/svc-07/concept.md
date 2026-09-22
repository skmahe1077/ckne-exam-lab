# Concept: kube-proxy Modes and Behaviour

kube-proxy is the component that turns a Service's stable virtual IP
(`ClusterIP`) into real traffic delivery to one of its backing Pods. It
runs as a DaemonSet (one Pod per node) and watches Services + EndpointSlices
through the API server; whenever they change, it reprograms the node's
packet-handling rules. It has three historical modes:

- **`iptables`** (this cluster's mode, and still the kubeadm default) —
  kube-proxy writes Linux `netfilter`/`iptables` rules into the node's
  **root network namespace**. For each Service it creates a `KUBE-SVC-*`
  chain, jumped to from `KUBE-SERVICES` when a packet's destination
  matches the Service's ClusterIP/port. That chain then jumps, with
  weighted random probability, into one `KUBE-SEP-*` (Service EndPoint)
  chain per ready backend Pod, which does the actual DNAT to that Pod's
  IP. Rule evaluation is roughly linear in the number of Services, which
  is the classic scaling complaint against this mode.
- **`ipvs`** — uses the kernel's IP Virtual Server instead, giving O(1)
  lookups and more load-balancing algorithms, at the cost of extra kernel
  module requirements. Not used in this cluster.
- **`nftables`** — a newer replacement backend, functionally similar to
  `iptables` mode but using the modern `nft` rule syntax. Not used in this
  cluster either.

This cluster explicitly keeps kube-proxy enabled and in `iptables` mode
(Cilium is installed with `kubeProxyReplacement=false`), so Service
routing here is a two-layer story: Cilium's eBPF datapath handles Pod
networking (CNI), while kube-proxy's iptables rules handle Service
ClusterIP → Pod IP translation.

**Why you can't just `iptables-save` inside a normal Pod:** every ordinary
Pod gets its own network namespace, separate from the node's. kube-proxy
writes its rules into the **node's** root network namespace — a Pod
sandboxed in its own netns has no visibility into them at all, regardless
of what capabilities it holds. The only way to see them from inside a Pod
is to make that Pod share the node's network namespace directly
(`hostNetwork: true`), and even then, actually querying netfilter state
requires the `NET_ADMIN` capability (and conventionally `NET_RAW`
alongside it for raw-socket tooling).
