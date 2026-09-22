# Hints — SEC-03

## Level 1

Check what currently exists — there is no NetworkPolicy yet, so both clients
can reach backend:

```bash
kubectl -n ckne-sec-03 get networkpolicy
kubectl -n ckne-sec-03 exec client-other -- wget -q -T 5 -O- http://backend
```

## Level 2

Confirm the label each client Pod actually carries — your `from` selector
has to match one of them and not the other:

```bash
kubectl -n ckne-sec-03 get pods --show-labels
```

## Level 3

Write a NetworkPolicy with `podSelector: {matchLabels: {app: backend}}`,
`policyTypes: [Ingress]`, and a single `ingress` entry whose `from` is a
`podSelector` matching `role: frontend`, restricted to `port: 80`/`TCP`.
Apply it, then re-run `make validate LAB=SEC-03`.
