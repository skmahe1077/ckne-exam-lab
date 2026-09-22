# CKNE-ATM-05 — Solution

## Root cause

`CiliumEgressGatewayPolicy` `ckne-atm-05-egress-policy`'s `podSelector` targets `app: wrong-app`, a label no Pod in `ckne-atm-05` carries — the `egress-client` Deployment's Pods are labeled `app: egress-client`. The policy applies cleanly and is valid, but it silently selects zero Pods, so nothing is ever redirected through the gateway node.

## Investigation process

Preconditions are already satisfied — egress gateway is enabled and `egress-client` is Ready:

```bash
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-egress-gateway}{"\n"}'
kubectl -n ckne-atm-05 get deployment egress-client
```

The policy exists and applied without error, but the CRD has no status field to check — ask a live Cilium agent instead:

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
```

No entry appears for `egress-client`'s Pod IP. Comparing the policy's selector against the Pod's real labels shows why:

```bash
kubectl get ciliumegressgatewaypolicy ckne-atm-05-egress-policy -o jsonpath='{.spec.selectors[0].podSelector.matchLabels}{"\n"}'
# {"app":"wrong-app"}
kubectl -n ckne-atm-05 get pods -l app=egress-client --show-labels
# app=egress-client
```

## Corrected configuration

```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: ckne-atm-05-egress-policy
spec:
  selectors:
    - podSelector:
        matchLabels:
          app: egress-client
      namespaceSelector:
        matchLabels:
          ckne.openai.com/lab-id: "ATM-05"
  destinationCIDRs:
    - "1.1.1.1/32"
  egressGateway:
    nodeSelector:
      matchLabels:
        ckne.openai.com/atm-05-egress-node: "true"
```

Equivalent inline patch (remember: cluster-scoped, no `-n`):

```bash
kubectl patch ciliumegressgatewaypolicy ckne-atm-05-egress-policy --type=json \
  -p '[{"op":"replace","path":"/spec/selectors/0/podSelector/matchLabels/app","value":"egress-client"}]'
```

## Verification steps

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf egress list
# Source IP       Destination CIDR   Egress IP   Gateway IP
# <pod-ip>        1.1.1.1/32         0.0.0.0     <gateway-node-internal-ip>
make validate LAB=ATM-05
```

An entry should now appear for `egress-client`'s Pod IP, showing destination `1.1.1.1/32` routed through the labeled gateway node.

## Why this works

`CiliumEgressGatewayPolicy` is cluster-scoped and selects source Pods via a combination of `podSelector` and `namespaceSelector`. If the `podSelector` doesn't match any real Pod's labels, the policy is a perfectly valid, applied object that silently selects nothing — the same "healthy-looking but empty" failure mode a Service with a wrong selector exhibits, just one layer down in the stack. Correcting `podSelector` to `app: egress-client` is what actually causes Cilium's datapath to program a Source-IP → Destination-CIDR → Gateway-IP mapping for those Pods; the `namespaceSelector`, `destinationCIDRs`, and `egressGateway.nodeSelector` were already correct and untouched. Because the CRD has no status subresource, the only reliable way to confirm the fix is asking a live agent what it actually compiled into the datapath via `cilium-dbg bpf egress list`, rather than trusting `kubectl describe`.

## Faster exam-oriented method

`kubectl get ciliumegressgatewaypolicy ckne-atm-05-egress-policy -o jsonpath='{.spec.selectors[0].podSelector.matchLabels}'` next to `kubectl get pods -n ckne-atm-05 --show-labels` — a `podSelector` value that doesn't appear in the Pod's real labels is the entire diagnosis. Patch that one field and re-check `cilium-dbg bpf egress list` for the new entry.

## Common mistakes

- Editing `destinationCIDRs`, `egressGateway.nodeSelector`, or `namespaceSelector` while hunting for the bug — all three are correct preconditions per the requirements; only `podSelector` is broken.
- Relabeling the `egress-client` Pods to match the policy instead of fixing the policy's selector — the requirements explicitly forbid changing Pod labels; the policy must be corrected instead.
- Trusting `kubectl describe ciliumegressgatewaypolicy` or "applied with no errors" as proof the policy is working — the CRD has no status field, so a selector matching zero Pods produces no visible error at all.
- Forgetting the CRD is cluster-scoped and adding `-n ckne-atm-05` to `kubectl get/patch ciliumegressgatewaypolicy` commands, which will fail to find the object.

## Relevant documentation

- Cilium Egress Gateway — https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/
- Kubernetes node assignment (nodeSelector) — https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- Helm upgrade reference — https://helm.sh/docs/helm/helm_upgrade/
