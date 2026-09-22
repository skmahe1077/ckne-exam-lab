# Concept: EndpointSlices and Readiness

A Service's `selector` decides which Pods are *candidates* for traffic, but
candidacy alone is not enough — Kubernetes only routes traffic to Pods that
are also **Ready**. The mechanism that connects the two is the
**EndpointSlice** API (`discovery.k8s.io/v1`), which replaced the older
monolithic `Endpoints` object.

For every Service, the EndpointSlice controller watches the Service's
selector and the matching Pods' status, and maintains one or more
EndpointSlice objects labeled `kubernetes.io/service-name=<service-name>`.
Each entry in `.endpoints[]` carries:

- `addresses` — the Pod's IP(s).
- `conditions.ready` — `true` only if the Pod's `Ready` condition is
  `true`, which itself only becomes `true` once every container in the Pod
  passes its `readinessProbe` (if one is defined; no probe means "ready as
  soon as Running").
- `targetRef` — which Pod this entry came from.

kube-proxy (and any other consumer, including Cilium's eBPF datapath in
this cluster) programs its load-balancing rules from the **ready**
addresses in the EndpointSlice, not from the Pod list directly. A Pod that
is `Running` but fails its readiness probe still exists, still has an IP,
and is still selected by the Service's label selector — but it is either
omitted from the EndpointSlice entirely or listed with
`conditions.ready: false`, and traffic is not sent to it. This is exactly
why "the Pods are Running" and "the Service works" are two different
claims: a misconfigured readiness probe can make a perfectly healthy
container invisible to its own Service.

The fix is always to make the probe accurately reflect real health — never
to remove it, which would make the Service send traffic to a Pod before
(or even if never) it is actually able to serve it.
