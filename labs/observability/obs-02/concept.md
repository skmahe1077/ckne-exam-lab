# Concept: CoreDNS Logs, Service and Endpoint Health

CoreDNS runs as a Deployment (`coredns`, in `kube-system`) with the default
kubeadm Corefile plugin chain: `errors`, `health`, `ready`, `kubernetes`,
`prometheus`, `forward`, `cache`, `loop`, `reload`, `loadbalance`. The
`errors` plugin logs any query that results in a real DNS-layer error
(e.g. a SERVFAIL from a broken upstream forward) to stdout — which is why
`kubectl -n kube-system logs -l k8s-app=kube-dns` is a legitimate first
diagnostic step for "nothing can reach my Service" reports.

But DNS and Service health are two separate, independently-failing layers:

- **DNS** answers the question "what ClusterIP does the name `orders`
  resolve to?" A Service's DNS record is created the moment the Service
  object exists in the API — it does **not** depend on the Service having
  any healthy backends. A Service with zero Ready Pods still resolves by
  name just fine; the resulting connection just has nowhere to go.
- **Endpoints/EndpointSlices** answer the question "which Pod IPs is this
  Service currently allowed to route to?" Only Pods that are **Ready**
  (passing their readinessProbe, not merely Running) are included. A Pod
  stuck `0/1 Running` because its readinessProbe never succeeds silently
  drops out of the Service's backend set — no Event on the Service itself,
  no DNS error, just an empty Endpoints list.

The diagnostic order that matters: check CoreDNS's logs and confirm name
resolution actually works before assuming DNS is broken, then move to
Endpoints — an empty Endpoints list with working DNS almost always means a
readiness problem, not a networking or DNS problem.
