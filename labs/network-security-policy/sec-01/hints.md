# Hints — SEC-01

## Level 1

Check what's currently applied and confirm both clients are blocked:

```bash
kubectl -n ckne-sec-01 get networkpolicy
kubectl -n ckne-sec-01 exec client-frontend -- wget -q -T 5 -O- http://backend
```

## Level 2

Look at the existing policy's shape — note it has no `ingress:` key at all:

```bash
kubectl -n ckne-sec-01 get networkpolicy default-deny-ingress -o yaml
```

Remember: NetworkPolicies selecting the same Pod are additive. You don't
need to touch this one — you need a second policy that contributes an allow
rule.

## Level 3

Write a new NetworkPolicy with `podSelector: {matchLabels: {app: backend}}`,
`policyTypes: [Ingress]`, and an `ingress` rule whose `from` is a
`podSelector` matching `role: frontend`, restricted to `port: 80`/`TCP`.
Apply it with `kubectl apply -f`, then re-run `make validate LAB=SEC-01`.
