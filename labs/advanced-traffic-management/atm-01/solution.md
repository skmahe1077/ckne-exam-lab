# Solution — ATM-01

## Diagnosis

```bash
kubectl -n ckne-atm-01 get httproute host-routes -o yaml
kubectl -n ckne-atm-01 get httproute host-routes-green -o yaml
kubectl -n ckne-atm-01 get httproute path-routes -o yaml
```

- `host-routes` has `hostnames: [blue.ckne.local]` but
  `rules[0].backendRefs[0].name: green`.
- `host-routes-green` has `hostnames: [green.ckne.local]` but
  `rules[0].backendRefs[0].name: blue`.
- `path-routes` has a `/blue` rule pointing at `backendRefs.name: green`,
  and a `/green` rule pointing at `backendRefs.name: blue`.

The Gateway and both backend Services/Deployments are already correct —
only the three HTTPRoute objects need their `backendRefs` fixed.

## Fix

See `manifests/expected/httproute-host.yaml` and
`manifests/expected/httproute-path.yaml` for the full corrected objects.
Equivalent inline patches:

```bash
kubectl -n ckne-atm-01 patch httproute host-routes --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"blue"}]'

kubectl -n ckne-atm-01 patch httproute host-routes-green --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"green"}]'

kubectl -n ckne-atm-01 patch httproute path-routes --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"blue"},
       {"op":"replace","path":"/spec/rules/1/backendRefs/0/name","value":"green"}]'
```

## Verify

```bash
GW_IP=$(kubectl -n ckne-atm-01 get svc cilium-gateway-atm-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-atm-01 run tmp --image=busybox:1.36 --restart=Never --rm -i --command -- \
  wget -q -O- --header="Host: blue.ckne.local" "http://$GW_IP/"
make validate LAB=ATM-01
```
