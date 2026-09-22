# Solution — SEC-09

## Part A — cert-manager Issuer + Certificate

### Diagnosis

No `Issuer` or `Certificate` exists yet in `ckne-sec-09` — this is entirely
additive.

### Fix

Apply `manifests/expected/certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ckne-sec-09-issuer
  namespace: ckne-sec-09
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: backend-cert
  namespace: ckne-sec-09
spec:
  secretName: backend-tls
  commonName: backend.ckne-sec-09.svc.cluster.local
  dnsNames:
    - backend.ckne-sec-09.svc.cluster.local
  issuerRef:
    name: ckne-sec-09-issuer
    kind: Issuer
    group: cert-manager.io
```

```bash
kubectl apply -f labs/network-security-policy/sec-09/manifests/expected/certificate.yaml
kubectl -n ckne-sec-09 wait --for=condition=Ready certificate/backend-cert --timeout=120s
```

### Verify

```bash
kubectl -n ckne-sec-09 get issuer ckne-sec-09-issuer
kubectl -n ckne-sec-09 get certificate backend-cert -o jsonpath='{.status.conditions}'
kubectl -n ckne-sec-09 get secret backend-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
```

## Part B — ServiceAccount identity

### Diagnosis

`backend-workload`'s Pod template never sets `spec.serviceAccountName`, so
its Pods silently run under the implicit `default` ServiceAccount instead
of the purpose-specific `backend-identity` that already exists in the
namespace.

### Fix

Apply `manifests/expected/backend-workload.yaml` (adds
`serviceAccountName: backend-identity` under `spec.template.spec` — the
only change from the starting Deployment):

```bash
kubectl apply -f labs/network-security-policy/sec-09/manifests/expected/backend-workload.yaml
kubectl -n ckne-sec-09 rollout status deployment/backend-workload --timeout=120s
```

`spec.serviceAccountName` is immutable on a running Pod, so this requires
the Deployment to roll new Pods — patching the Pod template (not the live
Pod) is what makes that happen.

### Verify

```bash
kubectl -n ckne-sec-09 get pod -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'   # backend-identity
make validate LAB=SEC-09
```
