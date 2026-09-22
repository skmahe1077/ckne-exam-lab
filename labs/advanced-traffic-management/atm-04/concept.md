# Concept: Gateway TLS Termination

A Gateway API `Gateway` listener with `protocol: HTTPS` and
`tls.mode: Terminate` needs a real Kubernetes `Secret` of type
`kubernetes.io/tls` to actually terminate TLS — `certificateRefs` points at
that Secret **by name**, in the Gateway's own namespace (unless a
`ReferenceGrant` allows cross-namespace, see SVC-10).

cert-manager is the piece that usually produces that Secret, but it does so
indirectly through two objects:

- An `Issuer` (or `ClusterIssuer`) — describes *how* to issue certificates
  (self-signed, an ACME account, a CA, etc.).
- A `Certificate` — describes *what* to issue (common name, DNS SANs,
  which Issuer to use) and, critically, **which Secret name to write the
  result into** (`spec.secretName`).

`certificateRefs` must name that `spec.secretName` value — **not** the
`Certificate` object's own `metadata.name`. These are frequently different
strings, and pointing a Gateway listener at the `Certificate`'s name
instead of the Secret it actually produces is a common, easy mistake: the
Certificate itself will show `Ready: True` in isolation, and yet the
Gateway still can't terminate TLS, because it's looking for a Secret that
was never going to exist under that name.

Diagnosing this requires checking both layers independently: is the
`Certificate` actually `Ready` (did cert-manager succeed)? And separately,
does the `Secret` name the Gateway references actually match the one the
`Certificate` wrote to? Both can be true or false independently, and only
one specific combination — Certificate Ready *and* correct Secret name —
actually produces a working HTTPS listener.
