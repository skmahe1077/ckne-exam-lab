# CKNE-SVC-10 — Solution

## Root cause

No `ReferenceGrant` exists in `ckne-svc-10-backend`. The `HTTPRoute`'s cross-namespace `backendRef` (right Service name, right namespace, right port) is correctly written, but Gateway API requires the *target* namespace to explicitly consent to being referenced before the reference is honored — without that consent object, `web-route` reports `ResolvedRefs: False`, reason `RefNotPermitted`.

## Investigation process

```bash
kubectl -n ckne-svc-10 get gateway svc10-gw
kubectl -n ckne-svc-10 get httproute web-route -o yaml
kubectl -n ckne-svc-10-backend get deployment,svc backend
```

`web-route`'s `status.parents[0].conditions` shows `ResolvedRefs: False`, reason `RefNotPermitted`.

```bash
kubectl -n ckne-svc-10-backend get referencegrant
# No resources found
```

`RefNotPermitted` means nothing about the `HTTPRoute`'s own YAML is wrong — a separate object is required in the *referenced* namespace, not the one the `HTTPRoute` lives in.

## Corrected configuration

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-svc10-httproutes
  namespace: ckne-svc-10-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: ckne-svc-10
  to:
    - group: ""
      kind: Service
      name: backend
```

```bash
kubectl apply -f labs/service-networking-dns/svc-10/manifests/expected/referencegrant.yaml
```

## Verification steps

```bash
kubectl -n ckne-svc-10 get httproute web-route -o jsonpath='{.status.parents[0].conditions}'
# ResolvedRefs: True

GW_IP=$(kubectl -n ckne-svc-10 get svc cilium-gateway-svc10-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-svc-10 run check --image=busybox:1.36 --rm -it --restart=Never \
  -- wget -qO- "http://${GW_IP}/"
# svc10-backend

make validate LAB=SVC-10
```

## Why this works

Kubernetes' normal RBAC model controls who can create/read/modify an object, not whether object A in namespace X is allowed to *point at* object B in namespace Y — without an extra guardrail, a team controlling an `HTTPRoute` could silently route traffic to a Service in someone else's namespace with no consent from that namespace's owner. `ReferenceGrant` closes that gap: it's a namespaced object, but it must be created in the namespace being referenced *into* (the target), not the one doing the referencing (the source). It says, in effect, "I consent to being referenced by objects of kind X from namespace Y, for objects of kind Z in my namespace." Only once that consent object exists does Cilium's Gateway controller honor the cross-namespace reference. Creating the grant in `ckne-svc-10-backend` — matching `from: HTTPRoute in ckne-svc-10` and `to: Service backend` — is exactly the consent Gateway API is waiting for; nothing about the `Gateway`, `HTTPRoute`, or `backend` itself was ever wrong.

## Faster exam-oriented method

`kubectl get httproute web-route -o jsonpath='{.status.parents[0].conditions}'` showing `RefNotPermitted` is the immediate signal to create a `ReferenceGrant` — no need to inspect the `HTTPRoute`'s `backendRef` fields for typos, since the reason code already rules that out. One manifest in the *backend* namespace fixes it.

## Common mistakes

- Creating the `ReferenceGrant` in `ckne-svc-10` (the source/`HTTPRoute` namespace) instead of `ckne-svc-10-backend` (the target namespace) — this is the single most common mistake with `ReferenceGrant`; it must live in the namespace being referenced into, not the one doing the referencing.
- Editing the `HTTPRoute`'s `backendRef` looking for a typo — the requirements state it's already correct, and `RefNotPermitted` specifically means the reference is well-formed but not consented to, not that it's malformed.
- Getting `spec.from`/`spec.to` backwards or using the wrong `group` values (e.g. omitting `group: ""` for the core `Service` API group) — both fields have a specific shape (`from` describes the referencing side, `to` describes what's being granted access to) that must match exactly for the grant to apply.
- Assuming the Gateway or GatewayClass needs reconfiguration — cross-namespace consent is entirely a `ReferenceGrant` concern, unrelated to Gateway listener or GatewayClass configuration.

## Relevant documentation

- Gateway API ReferenceGrant — https://gateway-api.sigs.k8s.io/reference/api-types/referencegrant/
- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/reference/api-types/httproute/
- Gateway API cross-namespace routing guide — https://gateway-api.sigs.k8s.io/guides/multiple-ns/
