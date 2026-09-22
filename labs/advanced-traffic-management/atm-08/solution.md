# CKNE-ATM-08 — Solution

## Root cause

The `streaming-route` HTTPRoute's `/slow` rule has no `timeouts` field at all — a caller hitting `/slow` can be left waiting for the backend's full delay with no bound, and the `/stream`/`/health` rule is correctly untouched.

## Investigation process

The Gateway, backend, and routing are all already healthy:

```bash
kubectl -n ckne-atm-08 get gateway atm-08-gw
kubectl -n ckne-atm-08 get deployment streaming-echo
```

Timing an unbounded request to `/slow` shows it takes the full backend delay, with no limit imposed by the route:

```bash
GW_IP=$(kubectl -n ckne-atm-08 get svc cilium-gateway-atm-08-gw -o jsonpath='{.spec.clusterIP}')
time kubectl -n ckne-atm-08 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -T 15 -O- "http://$GW_IP/slow?delay=8"
# ~8s
```

```bash
kubectl -n ckne-atm-08 get httproute streaming-route -o jsonpath='{.spec.rules}' | python3 -m json.tool
```

confirms the `/slow` rule has no `timeouts` key at all.

## Corrected configuration

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: streaming-route
  namespace: ckne-atm-08
spec:
  parentRefs:
    - name: atm-08-gw
  rules:
    - matches:
        - path: { type: PathPrefix, value: /slow }
      backendRefs:
        - name: streaming-echo
          port: 80
      timeouts:
        request: 3s
    - matches:
        - path: { type: PathPrefix, value: /stream }
        - path: { type: PathPrefix, value: /health }
      backendRefs:
        - name: streaming-echo
          port: 80
```

Equivalent inline patch:

```bash
kubectl -n ckne-atm-08 patch httproute streaming-route --type=json \
  -p '[{"op":"add","path":"/spec/rules/0/timeouts","value":{"request":"3s"}}]'
```

`retry` is deliberately not configured anywhere — it's an Experimental-channel Gateway API field and this cluster only installs the Standard channel CRDs; the timeout alone is the correct, available fix.

## Verification steps

```bash
GW_IP=$(kubectl -n ckne-atm-08 get svc cilium-gateway-atm-08-gw -o jsonpath='{.spec.clusterIP}')

# /slow should now fail/return well before 8s:
time kubectl -n ckne-atm-08 run tmp1 --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -T 12 -O- "http://$GW_IP/slow?delay=8"

# /stream should still take ~5s and deliver all 5 chunks:
time kubectl -n ckne-atm-08 run tmp2 --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -T 20 -O- "http://$GW_IP/stream?chunks=5&delay=1"

make validate LAB=ATM-08
```

## Why this works

Gateway API's `rules[].timeouts.request` field bounds how long the Gateway will wait for a backend to respond before giving up and returning an error — leave it unset, and a slow backend call hangs for its full duration with no limit. The real risk of an unbounded wait isn't the hang itself: a caller (or a naive retry wrapper) that gives up waiting and immediately retries doesn't cancel the first request, so a second full-price request lands on a backend that's already mid-flight on the first one, compounding the very slowness that triggered the retry. A bounded timeout turns that unbounded wait into a fast, predictable failure instead. `/stream` must not get the same timeout because `timeouts.request` applies to the whole request/response, and a streamed response can legitimately take as long as the backend takes to finish emitting chunks — cutting it off would kill a healthy, in-progress stream. Scoping the timeout to only the `/slow` rule (its own `matches`/`backendRefs`/`timeouts` block, independent of the `/stream` and `/health` rule) is what lets one risky path get bounded without affecting the other.

## Faster exam-oriented method

`kubectl get httproute streaming-route -o jsonpath='{.spec.rules}' | python3 -m json.tool` — spot the rule matching `/slow` with no `timeouts` key. Patch in `timeouts.request: 3s` on that rule only (JSON patch or `kubectl edit`) and re-time both `/slow` and `/stream` once to confirm the timeout bites on one and not the other.

## Common mistakes

- Adding `timeouts.request` to the `/stream`+`/health` rule as well "for consistency" — this cuts off a legitimately slow, healthy stream and fails the `/stream?chunks=5&delay=1` verification, which expects the full ~5-second incremental delivery to succeed.
- Reaching for `HTTPRoute`'s `retry` field instead of (or in addition to) a timeout — it's an Experimental-channel Gateway API field not installed in this cluster's Standard-channel CRDs, and even where available, retrying a slow backend without a timeout first only compounds load on an already-struggling backend.
- Setting the timeout value outside the required 1s–4s window — too short risks flaking the legitimate (non-8s) `/slow` calls used elsewhere; too long defeats the point of bounding the wait, and the task specifically requires a value in that range.
- Verifying only that the YAML now contains a `timeouts` block, without actually timing a real request through the Gateway — the requirement is that the timeout is enforced in practice, not just present in the spec.

## Relevant documentation

- Gateway API HTTPRoute timeouts — https://gateway-api.sigs.k8s.io/guides/http-timeouts/
- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/reference/api-types/httproute/
- Cilium Gateway API — https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
