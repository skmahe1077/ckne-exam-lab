# Concept: Cilium Cluster Mesh — Service Discovery

**Cluster Mesh** connects multiple independent Kubernetes clusters' Cilium
installations into one flat identity and service domain: Pods in one cluster
can be addressed, secured, and load-balanced to from another, without a
service mesh sidecar or an external API gateway in between. The control-plane
piece that makes this possible is the `clustermesh-apiserver` — a Deployment
(with an accompanying Service) that each cluster runs in `kube-system`. It
exposes that cluster's Cilium state (nodes, identities, and any Services
marked as "global") to the other clusters in the mesh over an mTLS-secured
connection, using etcd underneath.

Connecting two clusters into a mesh (`cilium clustermesh connect`, done once
in either direction) requires each cluster's `clustermesh-apiserver` to be
reachable from the other and to trust each other's certificates — which is
why enabling Cluster Mesh always involves generating a consistent set of TLS
materials (a server cert, and admin/remote/local client certs for the
different connection roles) as fixed-name Secrets:
`clustermesh-apiserver-server-cert`, `-admin-cert`, `-remote-cert`, and
`-local-cert`, each holding a `tls.crt`/`tls.key`/`ca.crt` triple.

Once clusters are meshed, **service discovery** across them is opt-in per
Service, via the `service.cilium.io/global: "true"` annotation. A Service
without this annotation behaves exactly as it always did — purely local to
its own cluster. Add the annotation, and Cilium starts treating any Service
with the *same name and namespace* in every connected cluster as one logical
"global service" — the annotation is what tells Cilium "this Service is
meant to be discovered and load-balanced across the whole mesh," not just
within this cluster.

## Scope limitation — read this before starting

**This environment has only one real Kubernetes cluster** (1 control-plane +
2 workers). There is no second cluster to connect to, and this lab does not
attempt to fake one. What this lab exercises instead:

- Deploying the `clustermesh-apiserver` control-plane component and
  confirming it (and its generated certificates) are healthy and
  well-formed.
- Correctly annotating a Service so that it is *ready* to be discovered by a
  remote cluster, the moment one is connected.

It deliberately does **not** claim to prove actual cross-cluster service
discovery works — that would require a second real cluster and the
`cilium clustermesh connect` step, neither of which exist here. Think of
this lab as "is the airport's customs desk open and correctly staffed,"
not "did the flight actually land" — a necessary, testable precondition for
cross-cluster discovery, but not the whole system.
