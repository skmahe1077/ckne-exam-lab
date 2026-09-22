# Hints — ATM-02

## Level 1

Look at what's already routing traffic:

```bash
kubectl -n ckne-atm-02 get httproute header-routes -o yaml
kubectl -n ckne-atm-02 get svc stable canary
```

Notice there is currently exactly one rule, and it has no `headers` match
at all — every request falls into it.

## Level 2

Check the Gateway API reference for `HTTPRouteMatch` and look specifically
at the `headers` field — it's a list of `{type, name, value}` objects,
siblings of `path` inside the same `matches` entry:

```bash
kubectl explain httproute.spec.rules.matches.headers
```

## Level 3

Add a second rule to `header-routes` (or a second `matches` entry backed by
its own `backendRefs`) that requires header `X-Canary` with `value: "true"`
(`type: Exact`, the default) and forwards to `backendRefs: [{name: canary,
port: 80}]`. Keep the existing header-less rule pointing at `stable` — it
becomes the fallback for every request that doesn't carry the header (or
carries a different value). List order between the two rules does not
matter for correctness, since the Gateway API's own rule-precedence rules
already favor the more specific (header-matching) rule.
