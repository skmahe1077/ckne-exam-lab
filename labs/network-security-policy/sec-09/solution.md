# CKNE-SEC-09 — Solution

## Root cause

No cert-manager `Issuer`/`Certificate` exists yet in `ckne-sec-09` (Part A is entirely additive). Separately, `backend-workload`'s Pod template never sets `spec.serviceAccountName`, so its Pods silently run under the implicit `default` ServiceAccount instead of the purpose-specific `backend-identity` that already exists in the namespace (Part B).

## Investigation process

```bash
kubectl -n ckne-sec-09 get issuer,certificate,secret
kubectl -n ckne-sec-09 get pod -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'
kubectl -n ckne-sec-09 get serviceaccount
```

**Part A:** no `Issuer`/`Certificate` objects exist. **Part B:** the running Pod reports `serviceAccountName: default`, while `backend-identity` already exists unused.

## Corrected configuration

**Part A — cert-manager Issuer + Certificate:**

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

**Part B — ServiceAccount identity:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-workload
  namespace: ckne-sec-09
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      serviceAccountName: backend-identity
      containers:
        - name: backend
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

```bash
kubectl apply -f labs/network-security-policy/sec-09/manifests/expected/backend-workload.yaml
kubectl -n ckne-sec-09 rollout status deployment/backend-workload --timeout=120s
```

`spec.serviceAccountName` is immutable on a running Pod, so this requires the Deployment to roll new Pods — patching the Pod template (not the live Pod) is what makes that happen.

## Verification steps

```bash
kubectl -n ckne-sec-09 get issuer ckne-sec-09-issuer
kubectl -n ckne-sec-09 get certificate backend-cert -o jsonpath='{.status.conditions}'
kubectl -n ckne-sec-09 get secret backend-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
kubectl -n ckne-sec-09 get pod -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'   # backend-identity
make validate LAB=SEC-09
```

## Why this works

An `Issuer` is namespaced — it can only issue `Certificate`s in the same namespace — which is why this lab deliberately uses one instead of a `ClusterIssuer`: it stays fully self-contained inside `ckne-sec-09`, needs no shared-resource lock, and is removed automatically when the namespace is deleted. `selfSigned: {}` is the simplest possible backend — cert-manager generates a key and signs the certificate with itself. A `Certificate` being "issued" isn't a one-time assumption: cert-manager reports it via a `Ready` condition, and only then has it written real key material into the target Secret — checking `Ready: True` *and* that `tls.crt`/`tls.key` are non-empty are two different, both-necessary checks, since a `Certificate` can exist without ever reaching `Ready`. Separately, `spec.serviceAccountName` identifies *who the Pod is* to the API server (a completely different concept from a TLS server certificate, which identifies what a server presents to a client) — setting it in the Pod template and letting the Deployment roll new Pods is what actually changes the running identity, since the field can't be patched on an existing Pod.

## Faster exam-oriented method

Part A: apply the `Issuer`+`Certificate` pair in one manifest and `kubectl wait --for=condition=Ready certificate/backend-cert`. Part B: one-line check of `serviceAccountName`, then a single `serviceAccountName: backend-identity` addition to the Deployment's Pod template followed by `rollout status`.

## Common mistakes

- Checking only `Certificate` `Ready: True` without confirming the target Secret actually has non-empty `tls.crt`/`tls.key` — an incomplete verification; the task explicitly calls out that a Ready Certificate with an empty Secret would still be a failure.
- Using a `ClusterIssuer` instead of a namespaced `Issuer` — the requirements specifically call for an `Issuer`, since it keeps the object contained to `ckne-sec-09` without needing a shared cluster-wide lock.
- Trying to `kubectl edit`/`kubectl patch` a running Pod's `spec.serviceAccountName` directly — immutable on an existing Pod; the Deployment's Pod template must change so new Pods are rolled with the correct identity.
- Creating a new ServiceAccount instead of using the existing `backend-identity` — violates the requirement not to create a new one, and RBAC objects/`backend-identity` itself must not be touched.

## Relevant documentation

- cert-manager Issuer concepts — https://cert-manager.io/docs/concepts/issuer/
- cert-manager Certificate usage — https://cert-manager.io/docs/usage/certificate/
- cert-manager self-signed issuer — https://cert-manager.io/docs/configuration/selfsigned/
- Configure a ServiceAccount for a Pod — https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- Kubernetes TLS Secrets — https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
