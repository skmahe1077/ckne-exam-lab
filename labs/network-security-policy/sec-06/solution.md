# Solution — SEC-06

## Diagnosis

`restrict-backend-ingress` currently has one `ipBlock` peer:

```yaml
ingress:
  - from:
      - ipBlock:
          cidr: 10.244.0.0/16
```

This allows ingress from the entire cluster Pod CIDR, so both `client-a`
(on the node recorded as `node-a`) and `client-b` (on `node-b`) can reach
`backend`. The task requires excluding `client-b`'s node's Pod CIDR
sub-range specifically, while still allowing the rest of the cluster
(including `client-a`'s node).

Look up the sub-range to exclude:

```bash
kubectl -n ckne-sec-06 get configmap node-cidrs -o jsonpath='{.data.node-b-cidr}'
```

## Fix

See `manifests/expected/networkpolicy.yaml` for the target shape (it uses
`${NODE_B_CIDR}` as a placeholder since the real value is cluster-specific —
substitute the literal CIDR you looked up above). Patch the live object:

```bash
NODE_B_CIDR="$(kubectl -n ckne-sec-06 get configmap node-cidrs -o jsonpath='{.data.node-b-cidr}')"
kubectl -n ckne-sec-06 patch networkpolicy restrict-backend-ingress --type=json \
  -p "[{\"op\":\"add\",\"path\":\"/spec/ingress/0/from/0/ipBlock/except\",\"value\":[\"${NODE_B_CIDR}\"]}]"
```

(Or `kubectl edit networkpolicy restrict-backend-ingress -n ckne-sec-06` and
add the `except:` list by hand.)

## Verify

```bash
kubectl -n ckne-sec-06 get networkpolicy restrict-backend-ingress -o yaml
kubectl -n ckne-sec-06 exec client-a -- wget -q -T5 -O- http://backend   # succeeds
kubectl -n ckne-sec-06 exec client-b -- wget -q -T5 -O- http://backend   # fails
make validate LAB=SEC-06
```

The rule now reads: allow ingress to `backend` from anywhere in
`10.244.0.0/16` except from the specific `/24` (or whatever mask the CNI
assigned) sub-range handed to `client-b`'s node — demonstrating `except` as
a hole carved out of a broader `cidr`, not a second independent rule.
