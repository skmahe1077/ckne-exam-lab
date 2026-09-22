# Concept: ClusterIP Services and Selectors

A Kubernetes `Service` is a stable virtual IP (the ClusterIP) plus a set of
routing rules that kube-proxy (or, on this cluster, Cilium's eBPF datapath)
programs on every node. The Service itself never proxies traffic to
"the Deployment" — it has no idea Deployments exist. It only knows about
**Pods that match `spec.selector`**.

The control loop that connects a Service to Pods is the **Endpoints
controller** (and, on modern clusters, EndpointSlices): it continuously
watches for Pods whose labels match the Service's selector, and writes
their IP:port pairs into an Endpoints/EndpointSlice object. kube-proxy /
Cilium then programs the actual forwarding rules purely from that list —
never from the selector directly.

This means a Service with a selector that matches **zero** Pods is a
perfectly valid, healthy-looking API object:

- `kubectl get svc` shows it with a ClusterIP assigned.
- `kubectl describe svc` shows the selector.
- But `kubectl get endpoints <svc>` shows `<none>`, and every connection to
  the ClusterIP fails (connection refused or times out, depending on
  whether *anything* is listening on that virtual IP path).

This is one of the most common real-world Service outages: a label typo,
a Deployment template's labels changed without updating the Service, or a
selector that was correct for a different Pod set entirely. The fix is
never on the Pod side unless the Pods are genuinely mislabeled — it's
almost always cheaper and safer to correct the Service's `spec.selector`
to match the labels the Pods already carry.

`targetPort` is a separate, independently-broken dimension: even with a
correct selector, if `targetPort` doesn't match the port the container is
actually listening on, Endpoints will still populate (Kubernetes doesn't
verify the container is listening) but connections will still fail. Always
check both.
