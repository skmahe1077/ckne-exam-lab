# Hints — ATM-05

## Level 1

Confirm the precondition state first, then look at what the policy actually
targets:

```bash
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-egress-gateway}{"\n"}'
kubectl -n ckne-atm-05 get deployment egress-client
kubectl get ciliumegressgatewaypolicy ckne-atm-05-egress-policy -o yaml
```

Remember `CiliumEgressGatewayPolicy` is cluster-scoped — there's no
`-n ckne-atm-05` on that last command.

## Level 2

The CRD has no status field, so `kubectl describe` won't tell you whether the
policy is actually doing anything. Ask a live Cilium agent instead:

```bash
kubectl -n ckne-atm-05 get pods -l app=egress-client --show-labels
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
```

Compare `spec.selectors[0].podSelector.matchLabels` in the policy against the
`show-labels` output. Does the egress list contain an entry for
`egress-client`'s Pod IP at all?

## Level 3

```bash
kubectl get ciliumegressgatewaypolicy ckne-atm-05-egress-policy -o jsonpath='{.spec.selectors[0].podSelector.matchLabels}{"\n"}'
```

The policy's `podSelector` doesn't match any label the `egress-client` Pods
actually carry. Patch (or `kubectl edit`) the policy's
`spec.selectors[0].podSelector.matchLabels` so it matches the Pod's real
`app` label, then re-check `cilium-dbg bpf egress list` — an entry for the
Pod's IP with destination `1.1.1.1/32` should appear within a few seconds.
