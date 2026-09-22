# Solution — ATM-04

## Diagnosis

```bash
kubectl -n ckne-atm-04 get certificate ckne-atm-04-cert -o jsonpath='{.spec.secretName}'
# ckne-atm-04-tls
kubectl -n ckne-atm-04 get gateway atm-gw -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}'
# ckne-atm-04-cert
```

The Gateway references `ckne-atm-04-cert` (the Certificate object's own
name), but the Certificate actually writes its keypair to a Secret named
`ckne-atm-04-tls`. No Secret named `ckne-atm-04-cert` exists, so the
listener has nothing to terminate TLS with.

## Fix

```bash
kubectl -n ckne-atm-04 patch gateway atm-gw --type=json \
  -p '[{"op":"replace","path":"/spec/listeners/0/tls/certificateRefs/0/name","value":"ckne-atm-04-tls"}]'
```

(see `manifests/expected/gateway.yaml` for the full corrected object)

## Verify

```bash
kubectl -n ckne-atm-04 get gateway atm-gw -o yaml   # listener Programmed/Accepted True
GW_IP=$(kubectl -n ckne-atm-04 get svc cilium-gateway-atm-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-atm-04 run checker --image=nicolaka/netshoot --restart=Never --rm -it -- \
  curl -sk --resolve atm04.ckne.local:443:$GW_IP https://atm04.ckne.local/
make validate LAB=ATM-04
```

The Issuer, Certificate, and HTTPRoute were never the problem — the entire
fix is one field on the Gateway.
