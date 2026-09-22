# Hints — SVC-09

## Level 1

Confirm what already exists (and doesn't) before writing anything:

```bash
kubectl get gatewayclass cilium
kubectl -n ckne-svc-09 get gateway,httproute
kubectl -n ckne-svc-09 get deployment,svc web
```

## Level 2

A `Gateway` needs a `gatewayClassName` (referencing the existing
`GatewayClass` by name), and at least one `listeners` entry (`protocol`,
`port`, and — if you want same-namespace `HTTPRoute`s to be allowed to
attach — `allowedRoutes`). Compare against ATM-01's or ATM-02's
`manifests/base/gateway.yaml` in this repo for the general shape (do not
copy their Gateway name — create your own).

## Level 3

Once your `Gateway` reports `Programmed=True`, find the Service Cilium
auto-created for it:

```bash
kubectl -n ckne-svc-09 get gateway <your-gateway-name> -o jsonpath='{.status.conditions}'
kubectl -n ckne-svc-09 get svc
```

Look for a Service named `cilium-gateway-<your-gateway-name>` — that's
what you send a real HTTP request to, to prove the whole chain
(`Gateway` → `HTTPRoute` → `web` Service) actually works.
