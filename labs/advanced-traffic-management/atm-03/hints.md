# Hints — ATM-03

## Level 1

Look at the current split:

```bash
kubectl -n ckne-atm-03 get httproute canary-split -o yaml
```

Find the `backendRefs` list under `spec.rules[0]` — there are two entries,
one per backend, each with a `weight`.

## Level 2

```bash
kubectl explain httproute.spec.rules.backendRefs.weight
```

Weight is relative, not absolute — `weight / sum-of-all-weights-in-the-rule`
is the fraction of traffic that backend receives. Currently both entries
have the same weight, which is why the split is even.

## Level 3

Edit the two `weight` fields under `spec.rules[0].backendRefs` so the
`stable` entry and the `canary` entry are in a 4:1 ratio (e.g. `80` and
`20`) — `kubectl edit httproute canary-split -n ckne-atm-03`, or a JSON
patch against `/spec/rules/0/backendRefs/0/weight` and
`/spec/rules/0/backendRefs/1/weight`. Double-check which array index is
`stable` and which is `canary` before patching — don't just assume the
order.
