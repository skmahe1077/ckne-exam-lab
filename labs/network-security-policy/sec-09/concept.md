# Concept: cert-manager Issuers/Certificates and ServiceAccount Identity

## cert-manager: Issuer vs. ClusterIssuer, and what "issued" really means

cert-manager (installed once, cluster-wide, by `kubeadm-setup/install-addons.sh`)
watches `Certificate` objects and, using the `Issuer`/`ClusterIssuer` each
one references, requests and stores a real X.509 keypair in a
Kubernetes `Secret` of type `kubernetes.io/tls` (keys `tls.crt`/`tls.key`).

- An `Issuer` is **namespaced** — it can only issue `Certificate`s that live
  in the same namespace. A `ClusterIssuer` is cluster-scoped and can issue
  for any namespace. This lab deliberately uses an `Issuer`, never a
  `ClusterIssuer`, because it must stay fully self-contained inside
  `ckne-sec-09` and needs no shared-resource lock — it is removed
  automatically the moment the namespace is deleted.
- `selfSigned: {}` is the simplest possible `Issuer` backend: cert-manager
  generates a key and signs the certificate with itself, no external CA or
  ACME account involved — appropriate for a lab, not for production
  internet-facing services.
- A `Certificate` being "issued" is not a static, one-time event you should
  just assume happened — cert-manager reports it via a `Ready` condition on
  the `Certificate` object, and only then has it actually written real
  key material into the target `Secret`. Checking `Ready: True` **and**
  that the Secret's `tls.crt`/`tls.key` fields are non-empty are two
  different, both-necessary checks — a `Certificate` can exist without ever
  reaching `Ready`, and inspecting only the `Certificate` object's status
  without confirming the `Secret` was actually populated is an incomplete
  verification.

## ServiceAccount identity

Every Pod runs under a `ServiceAccount` — implicitly `default` if the Pod
spec doesn't set `spec.serviceAccountName` explicitly. That identity is what
the Kubernetes API server, and (in more advanced setups like SEC-10's Istio
mTLS) the service mesh, uses to authenticate and authorize that Pod's own
requests — it is a completely separate concept from TLS server certificates:
a `ServiceAccount` identifies *who the Pod is*, a TLS `Certificate`
identifies *what a server presents to a client*. Running workloads under
purpose-specific `ServiceAccount`s (rather than leaving everything on
`default`) is a basic but frequently-skipped hardening step, because it lets
you scope RBAC `RoleBinding`s narrowly instead of granting broad permissions
to every Pod in a namespace via the shared `default` identity.
