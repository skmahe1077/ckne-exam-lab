# CKNE-SEC-06 — Solution

## Root cause

`restrict-backend-ingress`'s `ipBlock` allows ingress from the entire cluster Pod CIDR (`10.244.0.0/16`) with no `except` entry, so both `client-a` (on `node-a`) and `client-b` (on `node-b`) can reach `backend` — the policy needs to carve `client-b`'s node's Pod CIDR sub-range out of the otherwise-allowed range.

## Investigation process

```bash
kubectl -n ckne-sec-06 get configmap node-cidrs -o yaml
kubectl -n ckne-sec-06 get networkpolicy restrict-backend-ingress -o yaml
kubectl -n ckne-sec-06 get pod client-a client-b -o wide
```

Confirm both currently reach `backend`:

```bash
kubectl -n ckne-sec-06 exec client-a -- wget -q -T5 -O- http://backend
kubectl -n ckne-sec-06 exec client-b -- wget -q -T5 -O- http://backend
```

The `node-cidrs` ConfigMap has four keys: `node-a`, `node-a-cidr`, `node-b`, `node-b-cidr`. `client-b` was scheduled onto the node named in `node-b`, and its Pod IP falls inside `node-b-cidr`. The current policy's `ipBlock` entry has only a `cidr` key — no `except`.

## Corrected configuration

```bash
NODE_B_CIDR="$(kubectl -n ckne-sec-06 get configmap node-cidrs -o jsonpath='{.data.node-b-cidr}')"
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-backend-ingress
  namespace: ckne-sec-06
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - ipBlock:
            cidr: 10.244.0.0/16
            except:
              - "${NODE_B_CIDR}"   # actual value looked up above, e.g. 10.244.2.0/24
```

Equivalent inline patch:

```bash
kubectl -n ckne-sec-06 patch networkpolicy restrict-backend-ingress --type=json \
  -p "[{\"op\":\"add\",\"path\":\"/spec/ingress/0/from/0/ipBlock/except\",\"value\":[\"${NODE_B_CIDR}\"]}]"
```

## Verification steps

```bash
kubectl -n ckne-sec-06 get networkpolicy restrict-backend-ingress -o yaml
kubectl -n ckne-sec-06 exec client-a -- wget -q -T5 -O- http://backend   # succeeds
kubectl -n ckne-sec-06 exec client-b -- wget -q -T5 -O- http://backend   # fails
make validate LAB=SEC-06
```

## Why this works

An `ipBlock` peer matches purely on source IP, and `except` carves a hole out of an otherwise-allowed `cidr` — the effective allowed set becomes "everything in `cidr` that is not in any `except` entry," which is different from writing two disjoint `ipBlock` entries. Because each node is handed a stable sub-range of the cluster Pod CIDR under the default kubeadm allocate-node-cidrs setup, and every Pod scheduled on that node gets an IP from that sub-range, `node-b-cidr` is a durable proxy for "any Pod that ever runs on `client-b`'s node" — unlike an individual Pod IP, which changes on every reschedule. Adding `except: [node-b-cidr]` to the existing single `ipBlock` rule keeps the broad `10.244.0.0/16` allow in place for `client-a`'s node while specifically excluding `client-b`'s node's range.

## Faster exam-oriented method

`kubectl get configmap node-cidrs -o jsonpath='{.data.node-b-cidr}'` for the value, then one JSON patch adding `except` to the existing `ipBlock` — no need to re-derive the whole policy or touch `cidr`/`podSelector`.

## Common mistakes

- Adding a second `ipBlock` list entry instead of an `except` key inside the existing one — the task specifically requires a single `ipBlock` rule with `cidr`+`except`, not two separate rules, and grading checks for that exact shape.
- Hardcoding `client-b`'s current Pod IP instead of its node's CIDR sub-range — Pod IPs are ephemeral and change on reschedule; the node-to-subrange assignment is what's stable for the node's lifetime, which is the whole point of this lab.
- Changing `cidr` itself (e.g. narrowing it) instead of adding `except` — the requirement is to keep `cidr: 10.244.0.0/16` unchanged and carve out the exclusion separately.
- Using the wrong ConfigMap key (`node-b` instead of `node-b-cidr`) — `node-b` holds the node *name*, not its CIDR sub-range; only `node-b-cidr` is a valid value for `except`.

## Relevant documentation

- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- NetworkPolicy IPBlock reference — https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
- Declare a NetworkPolicy — https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
