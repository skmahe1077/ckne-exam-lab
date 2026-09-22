# Concept: Cilium Egress Gateway

By default, a Pod's traffic leaving the cluster is SNATed with the IP of
whichever node it happens to be running on. That's a problem the moment an
external system (a partner API, a legacy firewall, a SaaS allow-list) needs a
**stable, predictable source IP** for traffic coming from your workloads —
Pods get rescheduled across nodes constantly, so "the node's IP" is not
stable.

Cilium's **Egress Gateway** feature solves this by letting you designate one
or more nodes as the SNAT point for a specific set of Pods talking to a
specific set of external destinations. When a `CiliumEgressGatewayPolicy`
matches a packet, Cilium redirects it — even if the sending Pod is on a
different node — to the designated gateway node, which SNATs it with a
configured (or auto-selected) egress IP before it leaves the cluster. From
the external system's point of view, all matching traffic now appears to
come from one stable IP, regardless of which node or Pod actually generated
it.

This is a cluster-wide feature: `egressGateway.enabled` is a Cilium Helm
value, off by default, and turning it on affects every node's Cilium agent —
which is why this lab treats it as a shared, locked resource (see
`shared/scripts/lock.sh`) exactly like reconfiguring CoreDNS or kube-proxy
would be, rather than something a lab namespace can safely flip on its own.

The `CiliumEgressGatewayPolicy` CRD itself, unlike a `NetworkPolicy`, is
**cluster-scoped** — it has no `namespace` field. It selects source Pods via
a combination of `podSelector` and `namespaceSelector` (both label
selectors), a `destinationCIDRs` list of where the redirected traffic is
allowed to go, and an `egressGateway.nodeSelector` naming which node acts as
the SNAT point. If the `podSelector` doesn't match any real Pod's labels, the
policy is a perfectly valid, applied object that silently selects nothing —
the same "healthy-looking but empty" failure mode a Service with a wrong
selector exhibits (see SVC-01), just one layer down in the stack.

Because this is a cluster-scoped, datapath-level feature, the most reliable
way to confirm it's actually working isn't `kubectl describe` — the CRD has
no status subresource at all — but asking a live Cilium agent what it
actually programmed: `cilium-dbg bpf egress list` shows the real
Source-IP → Destination-CIDR → Gateway-IP mappings compiled into the
datapath, which is exactly what Cilium's own egress-gateway troubleshooting
guide uses to diagnose selector mismatches.
