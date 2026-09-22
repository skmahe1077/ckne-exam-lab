# Solution — ATM-02

## Diagnosis

```bash
kubectl -n ckne-atm-02 get httproute header-routes -o yaml
```

`header-routes` has a single rule with a `path: PathPrefix /` match and no
`headers` match, forwarding everything to `stable`. There is no rule for
the canary header at all.

## Fix

See `manifests/expected/httproute.yaml` for the full corrected object —
add a rule ahead of (or alongside) the existing one that matches header
`X-Canary: true` and forwards to `canary`:

```bash
kubectl -n ckne-atm-02 patch httproute header-routes --type=json -p '[
  {"op":"add","path":"/spec/rules/0","value":{
    "matches":[{"path":{"type":"PathPrefix","value":"/"},
                "headers":[{"type":"Exact","name":"X-Canary","value":"true"}]}],
    "backendRefs":[{"name":"canary","port":80}]
  }}
]'
```

## Verify

```bash
GW_IP=$(kubectl -n ckne-atm-02 get svc cilium-gateway-atm-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-atm-02 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: app.ckne.local" --header="X-Canary: true" "http://$GW_IP/"
make validate LAB=ATM-02
```
