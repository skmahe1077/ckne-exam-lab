# CKNE-SEC-01 — Solution

## Root cause

`default-deny-ingress` selects every Pod (`podSelector: {}`) with `policyTypes: [Ingress]` and no `ingress` rules — so no Pod in the namespace can receive any ingress traffic, including `client-frontend` talking to `backend`. There is no scoped allow rule yet for the legitimate client.

## Investigation process

```bash
kubectl -n ckne-sec-01 get networkpolicy
kubectl -n ckne-sec-01 exec client-frontend -- wget -q -T 5 -O- http://backend
```

The request from `client-frontend` fails even though it's the intended client. Look at the existing policy's shape:

```bash
kubectl -n ckne-sec-01 get networkpolicy default-deny-ingress -o yaml
```

It has no `ingress:` key at all — an empty `podSelector` with `policyTypes: [Ingress]` and zero allow rules, the idiomatic "deny all ingress" pattern.

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: ckne-sec-01
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
```

```bash
kubectl apply -f labs/network-security-policy/sec-01/manifests/expected/allow-frontend-to-backend.yaml
```

`default-deny-ingress` is left completely untouched.

## Verification steps

```bash
kubectl -n ckne-sec-01 exec client-frontend -- wget -q -T 5 -O- http://backend   # succeeds
kubectl -n ckne-sec-01 exec client-other    -- wget -q -T 5 -O- http://backend   # times out
make validate LAB=SEC-01
```

## Why this works

The moment any `NetworkPolicy` with `policyTypes: [Ingress]` selects a Pod, that Pod's ingress behavior flips from "allow everything" to "deny everything except what an Ingress rule explicitly allows." NetworkPolicies are additive (whitelist), not first-match/override — multiple policies can select the same Pod, and the effective allowed traffic is the union of every matching Ingress rule across all of them. `default-deny-ingress` contributes zero allow rules; `allow-frontend-to-backend` contributes exactly one: "from Pods labeled `role: frontend`, to Pods labeled `app: backend`, on TCP/80." The union is precisely "allow from `role: frontend`, deny everything else" — which is why adding a second, narrowly-scoped policy is correct instead of editing or deleting the deny policy.

## Faster exam-oriented method

`kubectl get networkpolicy default-deny-ingress -o yaml` — spotting `policyTypes: [Ingress]` with no `ingress` key confirms this is a default-deny-plus-missing-allow pattern, a very common NetworkPolicy shape. Write and apply the one scoped allow policy directly rather than investigating further.

## Common mistakes

- Editing or deleting `default-deny-ingress` to "fix" the block — violates the requirement to leave it in place, and removes the deny-by-default baseline every other Pod in the namespace should still get.
- Scoping the new policy's `from` too broadly (e.g. omitting the `podSelector` entirely, or using a `namespaceSelector` instead) — would let `client-other` through too, failing the requirement that it remain blocked.
- Forgetting `ports` on the new policy's ingress rule — without it, the rule would allow all ports from `role: frontend`, wider than the port-80-only requirement.
- Assuming NetworkPolicies override each other by specificity or order — they don't; every matching policy's rules combine additively, which is the whole reason a second, narrow policy is the correct fix here.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Declare a NetworkPolicy — https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
