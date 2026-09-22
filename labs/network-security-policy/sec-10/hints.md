# Hints — SEC-10

## Level 1

Confirm the mesh state before writing any policy:

```bash
kubectl get namespace ckne-sec-10 --show-labels
kubectl -n ckne-sec-10 get pods -o wide
kubectl -n ckne-sec-10 get pod trusted-caller -o jsonpath='{.spec.containers[*].name}'; echo
kubectl -n ckne-sec-10 get pod no-mesh-caller -o jsonpath='{.spec.containers[*].name}'; echo
kubectl -n ckne-sec-10 get peerauthentication,authorizationpolicy
```

Notice `no-mesh-caller` has only one container — no `istio-proxy` — by
design.

## Level 2

Test all three callers against `backend` BEFORE adding any policy, so you
have a clear "before" picture:

```bash
for p in trusted-caller untrusted-caller no-mesh-caller; do
  echo "$p:"; kubectl -n ckne-sec-10 exec "$p" -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local
done
```

All three currently succeed (HTTP 200) — that's the problem. After you add
the `PeerAuthentication`, re-run this loop: `no-mesh-caller` should already
start failing even before the `AuthorizationPolicy` exists.

## Level 3

`PeerAuthentication` in `ckne-sec-10`, no `selector`, `spec.mtls.mode:
STRICT` — see `manifests/expected/peer-authentication.yaml`.

`AuthorizationPolicy` in `ckne-sec-10`, `selector: {matchLabels: {app:
backend}}`, `action: ALLOW`, one rule with
`from[].source.principals: ["cluster.local/ns/ckne-sec-10/sa/trusted-caller-sa"]`
— see `manifests/expected/authorization-policy.yaml`. The principal string
must match the caller's actual ServiceAccount exactly (namespace and SA
name), or the allow rule will never match anyone.
