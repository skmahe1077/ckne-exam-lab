# Concept: ExternalName Services

`type: ExternalName` is the odd one out among Service types: it has no
selector, no Endpoints, no ClusterIP, and kube-proxy/Cilium's
service-proxy layer never touches it at all. It exists purely as a DNS
alias.

When CoreDNS's `kubernetes` plugin sees a query for
`<svc>.<namespace>.svc.cluster.local` and the matching Service object has
`type: ExternalName`, it answers with a **CNAME record pointing at
`spec.externalName`** instead of an A/AAAA record pointing at a ClusterIP.
The resolver that asked (typically the Pod's libc resolver, via the
`ndots`/search-domain logic configured by the Pod's `/etc/resolv.conf`)
then follows that CNAME exactly like any other DNS client would — CoreDNS
forwards the follow-up lookup for the external name upstream via its
`forward` plugin, out through whatever DNS servers this cluster is
configured to use, all the way out over the internet if the name is
public.

This makes ExternalName purely a **naming/DNS indirection** mechanism —
useful for giving workloads a stable, in-cluster-namespaced name for an
external dependency (a managed database, a third-party API, another
cluster) so the actual hostname can change later without touching every
workload that references it. Because there's no proxying involved, an
ExternalName Service can never provide port remapping, load balancing
across multiple external endpoints, or network policy enforcement the way
ClusterIP/NodePort/LoadBalancer Services can — it is DNS, and only DNS.

That also means "does this Service work" for ExternalName is really "does
this Service's DNS name resolve correctly" — there is no separate
data-plane routing test to run, because ExternalName sits entirely on the
control-plane/DNS side of the stack.
