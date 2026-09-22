# Hints — SEC-04

## Level 1

Check what's currently in each namespace and what's (not) protecting
`backend`:

```bash
kubectl -n ckne-sec-04 get networkpolicy
kubectl get namespace ckne-sec-04-clients --show-labels
```

## Level 2

A namespace-selector rule matches on the **namespace's own labels**, not
the Pod's labels and not physical/logical proximity. Compare:

```bash
kubectl get namespace ckne-sec-04 --show-labels
kubectl get namespace ckne-sec-04-clients --show-labels
```

Which one carries `network-access=trusted`? `untrusted-client` lives in the
namespace that doesn't.

## Level 3

Add a NetworkPolicy in `ckne-sec-04` with a `from.namespaceSelector`
(no `podSelector` on that `from` entry) matching
`network-access: trusted`, restricted to TCP port 80 — see
`manifests/expected/allow-trusted-namespace.yaml`.
