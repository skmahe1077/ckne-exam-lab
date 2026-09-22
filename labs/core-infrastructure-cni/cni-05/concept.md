# Concept: DNS Troubleshooting at Node and Pod Level

Kubernetes DNS resolution has two layers, and a failure can come from
either one independently:

**Cluster level.** CoreDNS runs as a Deployment in `kube-system`, exposed
via a `Service` (conventionally `kube-dns`) at a fixed ClusterIP. It
resolves in-cluster names (`<service>.<namespace>.svc.cluster.local`) and
forwards everything else upstream. If CoreDNS itself is down or its
Service has no working Endpoints, DNS breaks for *every* Pod in the
cluster simultaneously — this is the first thing to rule in or out,
because it changes where you should even be looking.

**Pod level.** Each Pod's own `/etc/resolv.conf` — and therefore which
nameserver(s) it actually queries — is controlled per-Pod by two fields:

- `dnsPolicy` (default `ClusterFirst`): use the cluster's CoreDNS Service
  IP, with cluster-domain search suffixes, falling back to the node's
  upstream resolvers for anything not in-cluster. Other values: `Default`
  (inherit the node's own `/etc/resolv.conf` directly, bypassing CoreDNS
  entirely for everything), and `None`.
- `dnsConfig`: when `dnsPolicy: None` is set, this field takes over
  completely — `nameservers`, `searches`, and `options` are used
  *instead of* the cluster default, with nothing else supplied unless you
  put it there yourself.

A single Pod can therefore have completely broken DNS — pointed at the
wrong (or an unreachable) nameserver — while CoreDNS, every other Pod, and
the rest of the cluster are entirely unaffected. `kubectl get pod -o yaml`
showing `dnsPolicy`/`dnsConfig`, and comparing `/etc/resolv.conf` between
the broken Pod and a normal sibling Pod, is the fastest way to see this:
the difference is visible immediately, and it explains a symptom
("resolution fails") that has nothing to do with CoreDNS's own health.

The diagnostic discipline that matters: check the cluster-wide layer
first (cheap, rules out the expensive investigation), then the Pod-level
layer (where a single misconfigured Pod actually lives).
