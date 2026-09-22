# Hints — ATM-08

## Level 1

Confirm the Gateway and backend are healthy before touching the HTTPRoute:

```bash
kubectl -n ckne-atm-08 get gateway atm-08-gw
kubectl -n ckne-atm-08 get deployment streaming-echo
kubectl -n ckne-atm-08 get httproute streaming-route -o yaml
```

Time an unbounded request yourself to see the problem directly:

```bash
GW_IP=$(kubectl -n ckne-atm-08 get svc cilium-gateway-atm-08-gw -o jsonpath='{.spec.clusterIP}')
time kubectl -n ckne-atm-08 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -T 15 -O- "http://$GW_IP/slow?delay=8"
```

Roughly how long does that take? Compare it to how long `/stream` takes for
the same total wall-clock budget.

## Level 2

Look at the Gateway API `HTTPRoute` spec for a field that bounds how long
the Gateway will wait for a backend response on a single rule, and note
which of the two rules in `streaming-route` it needs to go on — and which
one it must NOT go on.

```bash
kubectl -n ckne-atm-08 get httproute streaming-route -o jsonpath='{.spec.rules}' | python3 -m json.tool
```

## Level 3

Add a `timeouts` block under `spec.rules[].timeouts.request` to the rule
matching `/slow` only (see `manifests/expected/httproute.yaml`):

```bash
kubectl -n ckne-atm-08 patch httproute streaming-route --type=json \
  -p '[{"op":"add","path":"/spec/rules/0/timeouts","value":{"request":"3s"}}]'
```

Re-time the same `/slow?delay=8` request — it should now fail or return an
error noticeably before 8 seconds. Then re-time `/stream?chunks=5&delay=1`
and confirm it still takes close to 5 seconds and returns all 5 chunks —
that rule was never touched.
