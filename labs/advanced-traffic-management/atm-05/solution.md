# Solution — ATM-05

## Diagnosis

1. Preconditions are already satisfied — egress gateway is enabled and
   `egress-client` is Ready:

   ```bash
   kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-egress-gateway}{"\n"}'
   kubectl -n ckne-atm-05 get deployment egress-client
   ```

2. The policy exists and applied without error, but `cilium-dbg bpf egress
   list` shows no entry for `egress-client`'s Pod IP:

   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
   ```

3. Comparing the policy's selector against the Pod's real labels shows the
   mismatch:

   ```bash
   kubectl get ciliumegressgatewaypolicy ckne-atm-05-egress-policy -o jsonpath='{.spec.selectors[0].podSelector.matchLabels}{"\n"}'
   # {"app":"wrong-app"}
   kubectl -n ckne-atm-05 get pods -l app=egress-client --show-labels
   # app=egress-client
   ```

   The policy's `podSelector` looks for `app: wrong-app`, a label that no Pod
   in the namespace carries — so the policy is valid and applied, but
   silently selects zero Pods.

## Fix

Correct the `podSelector` (see `manifests/expected/egress-policy.yaml` for
the full corrected object):

```bash
kubectl patch ciliumegressgatewaypolicy ckne-atm-05-egress-policy --type=json \
  -p '[{"op":"replace","path":"/spec/selectors/0/podSelector/matchLabels/app","value":"egress-client"}]'
```

## Verify

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
# Source IP       Destination CIDR   Egress IP   Gateway IP
# <pod-ip>        1.1.1.1/32         0.0.0.0     <gateway-node-internal-ip>
make validate LAB=ATM-05
```

An entry should now appear for `egress-client`'s Pod IP, showing destination
`1.1.1.1/32` routed through the labeled gateway node. The
`namespaceSelector`, `destinationCIDRs`, and `egressGateway.nodeSelector`
were never the problem — only the `podSelector` needed to change.
