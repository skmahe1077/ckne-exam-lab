# CKNE-SEC-10 — Solution

## Root cause

`backend` has no `PeerAuthentication` and no `AuthorizationPolicy`, so despite having a sidecar, it currently accepts plaintext connections from `no-mesh-caller` and mTLS connections from any mesh identity, including `untrusted-caller`.

## Investigation process

Confirm the mesh state before writing any policy:

```bash
kubectl get namespace ckne-sec-10 --show-labels
kubectl -n ckne-sec-10 get pods -o wide
kubectl -n ckne-sec-10 get pod trusted-caller -o jsonpath='{.spec.containers[*].name}'; echo
kubectl -n ckne-sec-10 get pod no-mesh-caller -o jsonpath='{.spec.containers[*].name}'; echo
kubectl -n ckne-sec-10 get peerauthentication,authorizationpolicy
```

`no-mesh-caller` has only one container — no `istio-proxy` — by design. Test all three callers against `backend` before adding any policy:

```bash
for p in trusted-caller untrusted-caller no-mesh-caller; do
  echo "$p:"; kubectl -n ckne-sec-10 exec "$p" -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local
done
```

All three currently succeed (HTTP 200) — that's the problem.

## Corrected configuration

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: ckne-sec-10-strict-mtls
  namespace: ckne-sec-10
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: backend-allow-trusted-caller
  namespace: ckne-sec-10
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/ckne-sec-10/sa/trusted-caller-sa"
```

```bash
kubectl apply -f labs/network-security-policy/sec-10/manifests/expected/peer-authentication.yaml
kubectl apply -f labs/network-security-policy/sec-10/manifests/expected/authorization-policy.yaml
```

## Verification steps

```bash
kubectl -n ckne-sec-10 exec trusted-caller   -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local   # 200
kubectl -n ckne-sec-10 exec untrusted-caller -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local   # 403
kubectl -n ckne-sec-10 exec no-mesh-caller   -c client -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-10.svc.cluster.local   # 000 / connection failure
make validate LAB=SEC-10
```

## Why this works

Istio's sidecar answers two independent security questions. `PeerAuthentication` with `mode: STRICT` answers "is this connection even encrypted and mutually authenticated?" — the sidecar refuses any inbound connection that isn't mTLS, which alone is enough to reject `no-mesh-caller` (no sidecar, so no client certificate to present), regardless of identity. `AuthorizationPolicy` answers a separate question — "given the connection IS authenticated, is THIS caller allowed to do THIS?" — using SPIFFE-style principals derived from the caller's ServiceAccount (`cluster.local/ns/<namespace>/sa/<service-account-name>`). Once any `AuthorizationPolicy` selects a workload, that workload becomes default-deny for any principal not explicitly listed — so `untrusted-caller-sa`, a real, mTLS-authenticated mesh identity, is rejected with HTTP 403 just as much as a caller with no identity at all. Both controls are independent and both are required: `PeerAuthentication` alone doesn't restrict *which* mesh identity may connect, and `AuthorizationPolicy` alone doesn't stop plaintext callers without STRICT mTLS also in place.

## Faster exam-oriented method

Apply both reference objects together — `PeerAuthentication` with no `selector` (namespace-wide) and `mtls.mode: STRICT`, plus `AuthorizationPolicy` selecting `app: backend` with exactly one principal in the allow-list. Test all three callers in one loop afterward rather than one at a time.

## Common mistakes

- Creating the `PeerAuthentication` in `istio-system` or with no namespace scoping — applies mesh-wide, instantly changing TLS requirements for every other lab's namespace; it must be created IN `ckne-sec-10` so its blast radius is exactly this lab.
- Getting the `principals` string wrong (wrong namespace, wrong ServiceAccount name, or missing the `cluster.local/ns/.../sa/...` prefix) — the allow rule silently matches nobody if the principal string doesn't exactly match the caller's real identity.
- Adding only the `AuthorizationPolicy` and skipping `PeerAuthentication` — without STRICT mTLS, `no-mesh-caller`'s plaintext connection might still reach `backend` depending on the mesh's default TLS mode, since `AuthorizationPolicy` alone doesn't enforce encryption.
- Adding only the `PeerAuthentication` and skipping `AuthorizationPolicy` — stops `no-mesh-caller` but leaves `untrusted-caller-sa` (a legitimate, already-mTLS-authenticated mesh identity) fully able to reach `backend`, since nothing restricts *which* identity is allowed.

## Relevant documentation

- Istio PeerAuthentication — https://istio.io/latest/docs/reference/config/security/peer_authentication/
- Istio AuthorizationPolicy — https://istio.io/latest/docs/reference/config/security/authorization-policy/
- Istio mutual TLS concepts — https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication
- Istio HTTP authorization task — https://istio.io/latest/docs/tasks/security/authorization/authz-http/
