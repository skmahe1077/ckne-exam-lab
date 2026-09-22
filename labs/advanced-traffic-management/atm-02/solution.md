# CKNE-ATM-02 — Solution

## Root cause

`header-routes` has exactly one rule, a header-less `PathPrefix: /` match forwarding everything to `stable` — there is no rule at all for the `X-Canary` header, so no request can ever reach `canary`.

## Investigation process

```bash
kubectl -n ckne-atm-02 get httproute header-routes -o yaml
kubectl -n ckne-atm-02 get svc stable canary
```

The route has a single `matches` entry with only `path: {type: PathPrefix, value: /}` — no `headers` field anywhere in `spec.rules`. Both `stable` and `canary` Services/Deployments are already healthy; the gap is entirely in the route.

## Corrected configuration

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-routes
  namespace: ckne-atm-02
spec:
  parentRefs:
    - name: atm-gw
  hostnames:
    - app.ckne.local
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
          headers:
            - type: Exact
              name: X-Canary
              value: "true"
      backendRefs:
        - name: canary
          port: 80
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: stable
          port: 80
```

Equivalent inline patch (add the header-matching rule ahead of the existing catch-all):

```bash
kubectl -n ckne-atm-02 patch httproute header-routes --type=json -p '[
  {"op":"add","path":"/spec/rules/0","value":{
    "matches":[{"path":{"type":"PathPrefix","value":"/"},
                "headers":[{"type":"Exact","name":"X-Canary","value":"true"}]}],
    "backendRefs":[{"name":"canary","port":80}]
  }}
]'
```

## Verification steps

```bash
GW_IP=$(kubectl -n ckne-atm-02 get svc cilium-gateway-atm-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-atm-02 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: app.ckne.local" "http://$GW_IP/"                                   # -> stable-backend
kubectl -n ckne-atm-02 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: app.ckne.local" --header="X-Canary: true" "http://$GW_IP/"          # -> canary-backend
kubectl -n ckne-atm-02 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: app.ckne.local" --header="X-Canary: false" "http://$GW_IP/"         # -> stable-backend
make validate LAB=ATM-02
```

## Why this works

`spec.rules[].matches[].headers` lets a rule require one or more request headers at a specific value (`type: Exact` is the default) alongside its path match. Gateway API rule precedence ranks a rule with header matches above a header-less rule at the same path specificity, so the new `X-Canary: true` rule always wins for requests carrying that exact header value, regardless of where it sits in the `rules` list — every other request (wrong value or missing header) falls through to the untouched `stable` catch-all rule. This is why list order between the two rules doesn't need to be fought over, and why no second hostname or DNS entry is needed for the canary opt-in.

## Faster exam-oriented method

`kubectl get httproute header-routes -o yaml` — one rule, no `headers` field, is the whole diagnosis. Patch in the header rule with the JSON patch above (or `kubectl edit`) and curl twice (with and without the header) to confirm both paths.

## Common mistakes

- Replacing the existing rule instead of adding a new one — deleting the header-less `stable` rule breaks default (no-header) traffic, which the requirements explicitly still need to reach `stable`.
- Using `type: RegularExpression` or omitting `type` in a way that ends up matching header presence rather than the exact value `"true"` — the requirement that `X-Canary: false` still route to `stable` specifically tests for an exact-value match, not "header present."
- Editing the Gateway or GatewayClass to try to add routing logic — header matching is purely an `HTTPRoute` concept; the Gateway and GatewayClass are correct as-is.

## Relevant documentation

- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/reference/api-types/httproute/
- Gateway API HTTP routing guide — https://gateway-api.sigs.k8s.io/guides/http-routing/
- Cilium Gateway API — https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
