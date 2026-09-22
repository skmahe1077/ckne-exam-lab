# Solution — OBS-03

## Diagnosis

1. `kubectl -n ckne-obs-03 get networkpolicy web-policy -o yaml` shows the
   ingress rule allows `podSelector: {matchLabels: {role: blocked}}` — it
   allows `client-b` (role=blocked) and denies `client-a` (role=allowed),
   which is backwards from the intent implied by the labels.

2. Confirming with real traffic:

   ```bash
   kubectl -n ckne-obs-03 exec client-a -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
   # times out
   kubectl -n ckne-obs-03 exec client-b -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
   # succeeds
   ```

## Fix

Change the policy's `ingress.from` selector to `role: allowed` (see
`manifests/expected/networkpolicy.yaml`):

```bash
kubectl -n ckne-obs-03 patch networkpolicy web-policy --type=json \
  -p '[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/role","value":"allowed"}]'
```

## Verify with real traffic

```bash
kubectl -n ckne-obs-03 exec client-a -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
# succeeds
kubectl -n ckne-obs-03 exec client-b -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
# times out
```

## Verify with Hubble (the network-layer proof)

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
# find the agent Pod(s) on the node(s) running web/client-a/client-b

kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace ckne-obs-03 --last 100
```

Expect a line like:

```
... ckne-obs-03/client-a:xxxxx -> ckne-obs-03/web:80 to-endpoint FORWARDED (TCP Flags: SYN)
... ckne-obs-03/client-b:xxxxx -> ckne-obs-03/web:80 Policy denied DROPPED (Policy denied)
```

If a given agent Pod shows neither line, check the node it runs on
(`-o wide`) against the nodes hosting `web`, `client-a`, and `client-b` —
each agent only sees flows local to its own node.

```bash
make validate LAB=OBS-03
```

The exercise: Pod-status checks alone ("client-a is Running") never prove a
NetworkPolicy is enforcing the *right* rule — only a real request, and
Hubble's own record of Cilium's actual FORWARDED/DROPPED decision, prove it.
