# CKNE-ATM-04

**Task ID:** CKNE-ATM-04
**Domain:** Advanced Traffic Management
**Difficulty:** Intermediate
**Estimated time:** 30 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-atm-04
**Context:** default

## Scenario

A `Gateway` (`atm-gw`, referencing the shared `cilium` GatewayClass) has an HTTPS listener on port 443 configured to terminate TLS, and an `HTTPRoute` already correctly attaches to it and forwards to a `web` backend. A cert-manager `Issuer` + `Certificate` mint a self-signed TLS Secret named `ckne-atm-04-tls`. HTTPS requests currently fail — TLS never terminates.

## Objective

Get the Gateway's HTTPS listener to actually terminate TLS using the cert-manager-issued certificate, so a real HTTPS request through the Gateway succeeds end-to-end.

## Requirements

- Do not modify the `Issuer`, `Certificate`, or `HTTPRoute` — they are already correct.
- Find exactly why the Gateway's `https` listener cannot find its TLS material.
- Fix the Gateway's `certificateRefs` with the minimum change necessary.
- Confirm the Secret referenced actually exists and holds a valid keypair (it is produced automatically by the Certificate once the Issuer succeeds).
- Confirm an HTTPS request to the Gateway (SNI `atm04.ckne.local`) completes a real TLS handshake and reaches the `web` backend.

## Verification criteria

- The cert-manager `Certificate` in `ckne-atm-04` reports `Ready: True`.
- The Gateway's `https` listener reports `Programmed`/`Ready` (or equivalent Accepted condition) `True`.
- A real TLS handshake against the Gateway's Service on port 443 with SNI `atm04.ckne.local` succeeds (no handshake failure) and the presented certificate's subject/SAN matches `atm04.ckne.local`.
- An HTTPS request through that connection reaches the `web` backend and returns its response body.

## Permitted references

- Gateway API TLS configuration — https://gateway-api.sigs.k8s.io/guides/tls/
- cert-manager Issuer/Certificate concepts — https://cert-manager.io/docs/concepts/
- cert-manager usage — https://cert-manager.io/docs/usage/certificate/
