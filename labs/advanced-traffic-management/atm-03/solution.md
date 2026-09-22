# Solution — ATM-03

## Diagnosis

```bash
kubectl -n ckne-atm-03 get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs}'
```

Both `stable` and `canary` backendRefs have `weight: 1`, giving an even
50/50 split instead of the required 80/20.

## Fix

See `manifests/expected/httproute.yaml` for the full corrected object:

```bash
kubectl -n ckne-atm-03 patch httproute canary-split --type=json -p '[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":80},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":20}
]'
```

(Confirm index 0 is `stable` and index 1 is `canary` with `kubectl get
httproute canary-split -o yaml` before patching by index — if the order
differs, patch by matching `name` instead.)

## Verify

```bash
kubectl -n ckne-atm-03 get httproute canary-split -o jsonpath='{.spec.rules[0].backendRefs}'
make validate LAB=ATM-03
```

`validate.sh` samples 40 real requests through the Gateway and accepts any
observed split within +/-25 percentage points of 80/20 — see task.md for
why an exact match isn't required.
