# CKNE-ATM-03 — Solution

## Root cause

HTTPRoute `canary-split` has `stable` and `canary` `backendRefs` both set to `weight: 1`, giving an even 50/50 split instead of the required 80/20.

## Investigation process

```bash
kubectl -n ckne-atm-03 get httproute canary-split -o yaml
kubectl -n ckne-atm-03 get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs}'
```

Both `backendRefs` entries under `spec.rules[0]` carry `weight: 1` — equal weights, hence an even split.

## Corrected configuration

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-split
  namespace: ckne-atm-03
spec:
  parentRefs:
    - name: atm-gw
  hostnames:
    - app.ckne.local
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: stable
          port: 80
          weight: 80
        - name: canary
          port: 80
          weight: 20
```

Equivalent inline patch (confirm array index order first — patch by index only after verifying index 0 is `stable` and index 1 is `canary`):

```bash
kubectl -n ckne-atm-03 patch httproute canary-split --type=json -p '[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":80},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":20}
]'
```

## Verification steps

```bash
kubectl -n ckne-atm-03 get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs}'
make validate LAB=ATM-03
```

`validate.sh` samples 40 real requests through the Gateway and accepts any observed split within the [55%,100%] stable / [0%,45%] canary bands (±25 points around 80/20) — see task.md for why an exact match isn't required.

## Why this works

Gateway API distributes requests across a rule's `backendRefs` in proportion to `weight / sum(all weights in the rule)`, not as an absolute percentage — `80`/`20` behaves identically to `8`/`2` or `4`/`1`. Raising `stable`'s weight relative to `canary`'s shifts that proportion from 1:1 (50/50) to 4:1 (80/20) without touching anything about how requests are matched, so the Gateway, GatewayClass, and both backend Services/Deployments stay untouched. Because the split is enforced per-request by Envoy's own internal random selection, it is statistically accurate over many requests but not deterministic over a small sample — this is why `validate.sh` uses a wide tolerance band rather than expecting exactly 32/8 out of 40 requests.

## Faster exam-oriented method

`kubectl get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs}'` to see both weights at a glance, then a single JSON patch (or `kubectl edit`) to set them to `80`/`20`. No need to inspect the Gateway or backends — the task is entirely inside this one field.

## Common mistakes

- Patching by array index without first confirming which index is `stable` and which is `canary` — if the order differs from assumption, the ratio ends up inverted (20% to `stable`, 80% to `canary`).
- Setting an absolute-percentage mindset and using values that don't reduce to a 4:1 ratio (e.g. changing only one weight and leaving the other at `1`, producing an 80:1 ratio instead of 80:20).
- Expecting `validate.sh`'s 40-request sample to land on exactly 80/20 and "fixing" a passing but noisy result — the grader's tolerance band already accounts for this.
- Removing the `canary` backendRef entirely to "guarantee" more traffic to `stable` — the requirements explicitly require both backends stay reachable.

## Relevant documentation

- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/reference/api-types/httproute/
- Gateway API traffic-splitting guide — https://gateway-api.sigs.k8s.io/guides/traffic-splitting/
- Cilium Gateway API — https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
