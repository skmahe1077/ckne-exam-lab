# Hints — OBS-03

## Level 1

Confirm the current (backwards) behavior before touching anything:

```bash
kubectl -n ckne-obs-03 get networkpolicy web-policy -o yaml
kubectl -n ckne-obs-03 exec client-a -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
kubectl -n ckne-obs-03 exec client-b -- wget -q -T 5 -O- http://web.ckne-obs-03.svc.cluster.local
```

Which one currently succeeds? Compare that against each Pod's `role` label
(`kubectl -n ckne-obs-03 get pods --show-labels`).

## Level 2

Look at exactly what the policy's `ingress.from` selector matches:

```bash
kubectl -n ckne-obs-03 get networkpolicy web-policy -o yaml | grep -A3 podSelector
```

It selects a `role` value — but which one, and does that match the client
you want to allow?

## Level 3

Fix the selector, then find your Cilium agent Pods and query Hubble
directly (no need for `hubble-relay` — the CLI is bundled in every agent):

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace ckne-obs-03 --last 100
```

Look for one line with `client-a` and `FORWARDED`, and one line with
`client-b` and `DROPPED`. If you don't see both, try a different agent Pod —
each one only sees flows local to its own node.
