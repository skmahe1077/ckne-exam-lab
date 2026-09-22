# Concept: CoreDNS Configuration and Forwarding

CoreDNS is a plugin-chain DNS server: its whole behaviour is described by a
**Corefile**, a list of server blocks, each scoped to one or more zones and
a listening port (e.g. `.:53`, `cluster.local:53`,
`svc08test.example:53`). CoreDNS matches an incoming query's name against
the *most specific* zone it has a server block for, then runs that block's
plugin chain in order.

In a stock kubeadm cluster, `kube-system/coredns`'s Corefile has one server
block for `.` (everything) that chains together, among others:

- `kubernetes cluster.local in-addr.arpa ip6.arpa { ... }` — answers
  Service/Pod DNS names for the cluster.
- `forward . /etc/resolv.conf` — anything the `kubernetes` plugin didn't
  claim gets forwarded upstream, to whatever resolver the node itself
  uses.
- `reload` — watches the mounted Corefile file for changes and reloads
  CoreDNS's config in place, without a Pod restart, typically within
  under a minute.

**Adding a scoped forward for a specific zone** means adding a *new*,
separate server block for just that zone (e.g. `svc08test.example:53 {
forward . <upstream> }`), left alongside the existing `.` block rather than
editing it. CoreDNS matches the more specific zone first, so queries for
`*.svc08test.example` go to the new block's `forward` target, while every
other query (including all of `cluster.local`) is completely unaffected
and still flows through the original `.` block exactly as before. This is
the safe way to extend CoreDNS: a scoped addition cannot break the base
config, whereas a full ConfigMap replacement can.

Because `kube-system/coredns` is a single, cluster-wide ConfigMap shared by
every namespace and every other lab, editing it always carries real risk —
a syntax error or an accidentally-deleted `kubernetes` plugin line breaks
DNS resolution for the entire cluster, not just your own namespace. That is
why this kind of change is always done under a lock in this lab
environment, with the original content backed up first and restored
afterward.
