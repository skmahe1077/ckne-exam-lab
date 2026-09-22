# Hints — SEC-09

## Level 1

Check what cert-manager objects (if any) already exist, and what identity
`backend-workload` is currently running under:

```bash
kubectl -n ckne-sec-09 get issuer,certificate,secret
kubectl -n ckne-sec-09 get pod -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'
kubectl -n ckne-sec-09 get serviceaccount
```

## Level 2

For Part A, after creating the `Issuer`, watch the `Certificate` object's
`status.conditions` directly rather than assuming it's Ready:

```bash
kubectl -n ckne-sec-09 describe certificate
kubectl -n ckne-sec-09 get certificaterequest
```

If it's stuck, the `Certificate`'s Events or the referenced
`CertificateRequest` usually say exactly why (commonly: `issuerRef` pointing
at a name/kind that doesn't exist).

For Part B, `spec.serviceAccountName` can only be set on Pod *creation* —
editing a running Pod in place won't work; you need to change the
Deployment's Pod template so it recreates the Pods.

## Level 3

Part A: `Issuer` named `ckne-sec-09-issuer` with `spec: {selfSigned: {}}`,
and a `Certificate` with `secretName`, `dnsNames: [backend.ckne-sec-09.svc.cluster.local]`,
and `issuerRef: {name: ckne-sec-09-issuer, kind: Issuer, group: cert-manager.io}`
— see `manifests/expected/certificate.yaml`.

Part B: add `serviceAccountName: backend-identity` under
`spec.template.spec` in the `backend-workload` Deployment — see
`manifests/expected/backend-workload.yaml`.
