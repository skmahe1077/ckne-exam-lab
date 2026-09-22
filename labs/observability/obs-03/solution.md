# CKNE-OBS-03 — Solution

## Root cause

`web-policy`'s ingress `podSelector` allows `role: blocked` — the exact opposite of the intent. It allows `client-b` (role=blocked) and denies `client-a` (role=allowed), backwards from what the labels imply.

## Investigation process

Confirm the current (backwards) behavior before touching anything:

```bash
kubectl -n ckne-obs-03 get networkpolicy web-policy -o yaml
kubectl -n ckne-obs-03 exec client-a -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
# times out
kubectl -n ckne-obs-03 exec client-b -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
# succeeds
```

```bash
kubectl -n ckne-obs-03 get networkpolicy web-policy -o yaml | grep -A3 podSelector
```

The ingress rule's `from.podSelector` matches `role: blocked`, not `role: allowed`.

## Corrected configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-policy
  namespace: ckne-obs-03
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: allowed
      ports:
        - protocol: TCP
          port: 80
```

Equivalent inline patch:

```bash
kubectl -n ckne-obs-03 patch networkpolicy web-policy --type=json \
  -p '[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/role","value":"allowed"}]'
```

## Verification steps

Real traffic:

```bash
kubectl -n ckne-obs-03 exec client-a -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
# succeeds
kubectl -n ckne-obs-03 exec client-b -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
# times out
```

Network-layer proof via Hubble:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
# find the agent Pod(s) on the node(s) running web/client-a/client-b

kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace ckne-obs-03 --last 100
```

Expect lines like:

```
... ckne-obs-03/client-a:xxxxx -> ckne-obs-03/web:80 to-endpoint FORWARDED (TCP Flags: SYN)
... ckne-obs-03/client-b:xxxxx -> ckne-obs-03/web:80 Policy denied DROPPED (Policy denied)
```

If a given agent Pod shows neither line, check the node it runs on (`-o wide`) against the nodes hosting `web`, `client-a`, and `client-b` — each agent only sees flows local to its own node.

```bash
make validate LAB=OBS-03
```

## Why this works

Cilium's eBPF datapath makes a real forward/drop decision on every packet, and Hubble is the observability layer that records those decisions per-node in a bounded ring buffer, queryable via the `hubble` CLI bundled in every agent Pod without needing `hubble-relay` for a single targeted query. A `DROPPED ... Policy denied` flow is a positive, queryable event proving the packet reached Cilium's datapath and was intentionally rejected by policy — not lost to routing, not a DNS failure, not a crashed backend. Correcting the `podSelector` to `role: allowed` flips which client the NetworkPolicy actually admits; re-querying Hubble afterward proves the fix at the network layer itself (`FORWARDED` for `client-a`, `DROPPED` for `client-b`), rather than trusting Pod status alone, which says nothing about whether the *right* rule is being enforced.

## Faster exam-oriented method

`kubectl get networkpolicy web-policy -o yaml | grep -A3 podSelector` immediately shows the selector value — comparing it against the client labels (`role=allowed` vs `role=blocked`) makes the backwards rule obvious without needing to test traffic first. One JSON patch fixes it; Hubble is then used to *prove* the fix, not to find it.

## Common mistakes

- Modifying `client-a`, `client-b`, or the `web` Deployment/Service while diagnosing — the requirements are explicit that only `web-policy`'s selector needs to change; nothing else is broken.
- Treating a successful `wget` from `client-a` alone as sufficient proof — the task specifically requires confirming both the allow *and* the deny at the network layer via Hubble, not just that the intended client now succeeds.
- Querying only one Cilium agent Pod and concluding a flow "doesn't exist" when it wasn't observed — each agent only sees flows local to its own node; the right agent depends on where `web`, `client-a`, and `client-b` were actually scheduled.
- Modifying the cluster-wide Cilium/Hubble installation (e.g. enabling flags, restarting the DaemonSet) instead of just querying it — Hubble is already on and shared across every lab; nothing about its installation needs to change.

## Relevant documentation

- Cilium Hubble — https://docs.cilium.io/en/stable/observability/hubble/
- Hubble CLI — https://docs.cilium.io/en/stable/observability/hubble/hubble-cli/
- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
