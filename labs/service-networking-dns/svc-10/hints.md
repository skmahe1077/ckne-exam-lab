# Hints — SVC-10

## Level 1

Check what's already there, and what the HTTPRoute itself is reporting:

```bash
kubectl -n ckne-svc-10 get gateway svc10-gw
kubectl -n ckne-svc-10 get httproute web-route -o yaml
kubectl -n ckne-svc-10-backend get deployment,svc backend
```

Look at `web-route`'s `status.parents[].conditions` — is `ResolvedRefs`
`True` or `False`? What's the `reason`?

## Level 2

`RefNotPermitted` means exactly what it says: nothing about the
`HTTPRoute`'s own YAML is wrong — a separate object is required before a
reference INTO another namespace is honored. Which namespace does that
separate object need to live in: the one the `HTTPRoute` is in, or the one
being referenced?

```bash
kubectl -n ckne-svc-10-backend get referencegrant
```

## Level 3

A `ReferenceGrant` needs `spec.from` (which kind, from which namespace) and
`spec.to` (which kind, in this namespace). Create one in
`ckne-svc-10-backend` permitting `HTTPRoute`s from `ckne-svc-10` to
reference `Service`s here — see `manifests/expected/referencegrant.yaml`
for the exact shape (do not copy the reference's `metadata.name` verbatim
if you'd rather name it yourself; any name works).
