# Concept: Istio mTLS (PeerAuthentication) and AuthorizationPolicy

## Two different questions, two different objects

Istio's sidecar (`istio-proxy`, injected into every Pod in a namespace
labeled `istio-injection: enabled`) intercepts all Pod traffic and can
answer two separate security questions:

1. **"Is this connection even encrypted and mutually authenticated?"** —
   answered by `PeerAuthentication`. `mode: STRICT` means the sidecar will
   refuse any inbound connection that isn't mTLS — a caller with no sidecar
   at all (sending plain HTTP straight to the Pod) gets rejected outright,
   regardless of who it is.
2. **"Given that the connection IS authenticated, is THIS caller allowed to
   do THIS?"** — answered by `AuthorizationPolicy`. Istio identities are
   SPIFFE-style principals derived from the caller's ServiceAccount:
   `cluster.local/ns/<namespace>/sa/<service-account-name>`. An
   `AuthorizationPolicy` with `action: ALLOW` and a `from.source.principals`
   list is a default-deny allow-list once any `AuthorizationPolicy` selects
   a workload — only listed principals get through; every other
   already-mTLS-authenticated caller is still rejected (typically with
   HTTP 403 from the sidecar's RBAC filter, not a connection failure).

These are independent controls: `PeerAuthentication` alone stops
plaintext/no-sidecar callers but does not restrict *which* mesh identity may
connect. `AuthorizationPolicy` alone restricts identity but (without a
`PeerAuthentication` in `STRICT` mode) a workload might still also be
directly reachable over plaintext depending on the mesh's default TLS
mode. Getting the real security guarantee this lab asks for requires both.

## Why namespace-scoped, not mesh-wide

A `PeerAuthentication` with no `metadata.namespace` restriction — or one
created in `istio-system` with no workload `selector` — applies mesh-wide,
instantly changing the TLS requirements for every namespace in the cluster,
including every other lab. This lab's `PeerAuthentication` must be created
IN `ckne-sec-10` (no `selector`, which then means "every workload in *this*
namespace") so its blast radius is exactly this lab's own namespace — a
namespace-scoped Istio custom resource like this needs no
`shared/scripts/lock.sh` lock, unlike an actual mesh-wide/`istio-system`
change would.
