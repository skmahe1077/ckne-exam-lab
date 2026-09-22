# Hints — ATM-04

## Level 1

```bash
kubectl -n ckne-atm-04 get certificate ckne-atm-04-cert
kubectl -n ckne-atm-04 get gateway atm-gw -o yaml
```

The Certificate reports `Ready: True`. So why does the Gateway still fail
to terminate TLS?

## Level 2

```bash
kubectl -n ckne-atm-04 get certificate ckne-atm-04-cert -o jsonpath='{.spec.secretName}'
kubectl -n ckne-atm-04 get gateway atm-gw -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}'
```

Compare the two values. Do they match?

## Level 3

`certificateRefs` must name the **Secret** the Certificate writes to
(`spec.secretName`), not the Certificate object's own name. Patch the
Gateway's `certificateRefs[0].name` to the correct Secret name — see
`manifests/expected/gateway.yaml`.
