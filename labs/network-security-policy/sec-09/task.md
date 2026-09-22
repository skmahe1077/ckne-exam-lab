# CKNE-SEC-09

**Task ID:** CKNE-SEC-09
**Domain:** Network Security and Policy
**Difficulty:** Advanced
**Estimated time:** 35 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-sec-09
**Context:** default

## Scenario

`ckne-sec-09` has a `backend` Service fronting a `backend-workload` Deployment. Nothing cert-manager-related exists yet. A dedicated `ServiceAccount`, `backend-identity`, already exists in the namespace, but `backend-workload`'s Pods are not actually using it — they are still running under the implicit `default` ServiceAccount.

## Objective

Part A — create a working TLS certificate chain: a namespace-scoped, self-signed `Issuer` and a `Certificate` requesting a TLS keypair for the `backend` Service, and confirm cert-manager genuinely issues it. Part B — get `backend-workload`'s Pods running under the `backend-identity` ServiceAccount instead of `default`.

## Requirements

**Part A — cert-manager (namespace-scoped, no lock):**

- Create an `Issuer` (NOT a `ClusterIssuer`) named `ckne-sec-09-issuer` in `ckne-sec-09`, using `selfSigned: {}`.
- Create a `Certificate` in `ckne-sec-09` that references that `Issuer` and requests a keypair for `backend.ckne-sec-09.svc.cluster.local`, stored in a Secret you name (e.g. `backend-tls`).
- Confirm the `Certificate` reports `Ready: True`.
- Confirm the target Secret actually contains non-empty `tls.crt` and `tls.key` data — a `Ready` `Certificate` with an empty Secret would still be a failure.

**Part B — ServiceAccount identity (namespace-scoped, no lock):**

- Do not create a new ServiceAccount — `backend-identity` already exists.
- Update `backend-workload` so its Pod template sets `spec.serviceAccountName: backend-identity`.
- Do not change any RBAC objects, `backend-identity` itself, or the Service.
- `backend-workload` must return to Ready after the change, now running under the correct identity.

## Verification criteria

- `Issuer` `ckne-sec-09-issuer` exists in `ckne-sec-09` and is `Ready`.
- `Certificate` in `ckne-sec-09` reports `Ready: True`.
- Its target Secret contains non-empty `tls.crt` and `tls.key`.
- Deployment `backend-workload` is Ready.
- `backend-workload`'s Pod(s) report `spec.serviceAccountName == backend-identity` (not `default`).

## Permitted references

- cert-manager Issuer/Certificate concepts — https://cert-manager.io/docs/concepts/
- cert-manager self-signed issuer — https://cert-manager.io/docs/configuration/selfsigned/
- Kubernetes ServiceAccounts — https://kubernetes.io/docs/concepts/security/service-accounts/
