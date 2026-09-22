# Solution — ATM-08

## Diagnosis

1. The Gateway, backend, and routing are all already healthy:

   ```bash
   kubectl -n ckne-atm-08 get gateway atm-08-gw
   kubectl -n ckne-atm-08 get deployment streaming-echo
   ```

2. Timing an unbounded request to `/slow` shows it takes the full backend
   delay, with no limit imposed by the route:

   ```bash
   GW_IP=$(kubectl -n ckne-atm-08 get svc cilium-gateway-atm-08-gw -o jsonpath='{.spec.clusterIP}')
   time kubectl -n ckne-atm-08 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
     wget -q -T 15 -O- "http://$GW_IP/slow?delay=8"
   # ~8s
   ```

3. `kubectl -n ckne-atm-08 get httproute streaming-route -o yaml` confirms
   the `/slow` rule has no `timeouts` key at all.

## Fix

Add a request timeout to the `/slow` rule only (see
`manifests/expected/httproute.yaml` for the full corrected object):

```bash
kubectl -n ckne-atm-08 patch httproute streaming-route --type=json \
  -p '[{"op":"add","path":"/spec/rules/0/timeouts","value":{"request":"3s"}}]'
```

`retry` is deliberately not configured anywhere: it's an Experimental-channel
Gateway API field and this cluster only installs the Standard channel CRDs
(see concept.md) — the timeout alone is the correct, available fix for the
risk described in the scenario.

## Verify

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

The `/slow` rule now fails fast and predictably instead of hanging for the
full backend delay, while `/stream`'s incremental, multi-second delivery is
unaffected — proving the fix is scoped to exactly the rule that needed it.
