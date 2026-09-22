# CKNE-ATM-04 — Solution

## Root cause

The Gateway's `https` listener `certificateRefs` names `ckne-atm-04-cert` — the `Certificate` object's own `metadata.name` — instead of `ckne-atm-04-tls`, the Secret that Certificate's `spec.secretName` actually writes to. Since no Secret named `ckne-atm-04-cert` exists, the listener has nothing to terminate TLS with.

## Investigation process

```bash
kubectl -n ckne-atm-04 get certificate ckne-atm-04-cert
kubectl -n ckne-atm-04 get gateway atm-gw -o yaml
```

The `Certificate` reports `Ready: True` — cert-manager itself is not the problem. So compare what Secret name it actually produced against what the Gateway is looking for:

```bash
kubectl -n ckne-atm-04 get certificate ckne-atm-04-cert -o jsonpath='{.spec.secretName}'
# ckne-atm-04-tls
kubectl -n ckne-atm-04 get gateway atm-gw -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}'
# ckne-atm-04-cert
```

The two values don't match — the Gateway references a Secret name that was never going to exist.

## Corrected configuration

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: atm-gw
  namespace: ckne-atm-04
spec:
  gatewayClassName: cilium
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: ckne-atm-04-tls
      allowedRoutes:
        namespaces:
          from: Same
```

Equivalent inline patch:

```bash
kubectl -n ckne-atm-04 patch gateway atm-gw --type=json \
  -p '[{"op":"replace","path":"/spec/listeners/0/tls/certificateRefs/0/name","value":"ckne-atm-04-tls"}]'
```

## Verification steps

```bash
kubectl -n ckne-atm-04 get gateway atm-gw -o yaml   # listener Programmed/Accepted True
GW_IP=$(kubectl -n ckne-atm-04 get svc cilium-gateway-atm-gw -o jsonpath='{.spec.clusterIP}')
kubectl -n ckne-atm-04 run checker --image=nicolaka/netshoot --restart=Never --rm -it -- \
  curl -sk --resolve atm04.ckne.local:443:$GW_IP https://atm04.ckne.local/
make validate LAB=ATM-04
```

## Why this works

A `Gateway` listener's `certificateRefs` must name a Kubernetes `Secret` of type `kubernetes.io/tls` in the Gateway's own namespace — cert-manager produces that Secret indirectly: the `Issuer` describes *how* to issue, and the `Certificate` describes *what* to issue and, critically, which Secret name (`spec.secretName`) to write the result into. That Secret name is frequently different from the `Certificate` object's own `metadata.name`, and a listener referencing the wrong one fails silently from the Certificate's point of view — cert-manager still reports `Ready: True` because it did its job correctly, it just wrote to a Secret name nobody is looking at. Pointing `certificateRefs` at the actual `spec.secretName` value is what lets Cilium's Envoy datapath load the keypair and terminate TLS. The `Issuer`, `Certificate`, and `HTTPRoute` were never broken — this is a single-field mismatch entirely on the Gateway.

## Faster exam-oriented method

One-liner comparison: `kubectl get certificate ckne-atm-04-cert -o jsonpath='{.spec.secretName}'` next to `kubectl get gateway atm-gw -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}'` — a mismatch between these two values is the entire diagnosis for this class of bug. Patch the Gateway's `certificateRefs[0].name` to match and curl once to confirm.

## Common mistakes

- Editing the `Certificate` or `Issuer` looking for the bug — both are correct preconditions per the requirements; the mismatch is entirely on the Gateway side.
- Assuming `certificateRefs.name` should reference the `Certificate` object by name — Gateway API's `certificateRefs` always points at a `Secret`, never at a `Certificate` directly, regardless of how intuitive the opposite assumption feels.
- Stopping at "Certificate is Ready" and concluding TLS must be working — Ready only confirms cert-manager succeeded at issuing into *some* Secret; it says nothing about whether the Gateway is looking at the right one.
- Testing with plain HTTP instead of a real TLS handshake with the correct SNI (`atm04.ckne.local`) — an HTTP-only check would miss this bug entirely since it never touches the `https` listener.

## Relevant documentation

- Gateway API TLS guide — https://gateway-api.sigs.k8s.io/guides/tls/
- Kubernetes TLS Secrets — https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
- cert-manager Certificate usage — https://cert-manager.io/docs/usage/certificate/
- cert-manager self-signed issuer — https://cert-manager.io/docs/configuration/selfsigned/
