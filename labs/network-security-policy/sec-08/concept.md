# Concept: Cilium L3/L4/L7 Policy and Transparent Encryption

## L3/L4 vs. L7 — why a plain NetworkPolicy can't do this

A standard Kubernetes `NetworkPolicy` reasons about **L3 (IP/identity)** and
**L4 (protocol + port)** only: "Pod A may talk to Pod B on TCP/80" is as
specific as it gets. It has no concept of what happens *inside* that TCP/80
connection — it cannot distinguish `GET /health` from `POST /admin`; both
are indistinguishable "TCP port 80 traffic" to a plain `NetworkPolicy`.

`CiliumNetworkPolicy` (a CRD, namespace-scoped like any other Kubernetes
object — it needs no lock) can additionally express **L7 (application
layer)** rules for supported protocols including HTTP. When a
`CiliumNetworkPolicy` includes `rules.http`, Cilium transparently redirects
matching traffic through an embedded Envoy proxy on the node, which parses
the actual HTTP request and enforces method/path/header rules before
allowing (or rejecting, with an HTTP 403) the request — all without the
application or the client needing to be TLS-terminated, proxy-aware, or
modified in any way. This is strictly more expressive than L3/L4: you can
combine identity-based `fromEndpoints` (who) with HTTP-aware `toPorts.rules`
(what specifically they're allowed to do over that connection).

```yaml
ingress:
  - fromEndpoints:
      - matchLabels:
          app: caller
    toPorts:
      - ports:
          - port: "80"
            protocol: TCP
        rules:
          http:
            - method: "GET"
              path: "/health"
```

Once any `CiliumNetworkPolicy` selects an endpoint for `Ingress`, that
endpoint becomes default-deny for ingress — only traffic matching an
explicit rule is allowed. That means a Pod not covered by `fromEndpoints`
at all (like `outsider` in this lab) is blocked at L3/L4 before Envoy is
even involved, while a Pod that *is* an allowed source but sends a
request that doesn't match the `http` rule (like `caller` issuing
`POST /admin`) is blocked at L7 by Envoy.

## Transparent Encryption (WireGuard)

Independently of any policy, Cilium can encrypt **all** pod-to-pod traffic
between nodes at the datapath level using WireGuard, without the
application doing anything TLS-related itself — hence "transparent." This
is a **cluster-wide Cilium Helm configuration change** (`encryption.enabled`
/ `encryption.type`), not a namespaced object, so it is a genuinely
shared/singleton resource: exactly the kind of change that requires this
repo's `shared/scripts/lock.sh` (resource name `cilium-config`) so two labs
never fight over Cilium's Helm values at the same time. You cannot easily
prove wire-level encryption from inside a lab script without kernel/packet
capture access, so validation instead confirms Cilium's own reported
state (Helm-driven ConfigMap value and the running agent's own status
output) rather than trying to sniff the wire.
