Task ID: OBS-04
Domain: Observability
Difficulty: advanced
Estimated time: 30 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-obs-04

Scenario:
  A small app, `netmetrics`, was deployed into `ckne-obs-04`. It serves
  `/health`, `/hit` (increments an in-memory counter on every request), and
  `/metrics` (a Prometheus-format counter, `obs04_requests_total`) on port
  8080. Its Service carries the standard `prometheus.io/scrape`,
  `prometheus.io/path`, `prometheus.io/port` annotations that the cluster's
  shared Prometheus server (in the `monitoring` namespace, installed once by
  `kubeadm-setup/install-addons.sh`) uses to auto-discover scrape targets —
  but one of those annotations is wrong, so Prometheus has never
  successfully scraped this app.

Objective:
  Fix the Service's scrape annotation so Prometheus successfully scrapes
  `netmetrics`, then use real, in-cluster PromQL queries against
  Prometheus's HTTP API to prove metrics are actually flowing — both for
  `netmetrics` itself and for a core, always-on network component
  (`kube-apiserver`).

Requirements:
  1. Do not modify the `netmetrics` Deployment, ConfigMap, or ports — only
     the Service's `prometheus.io/*` annotations may need a change.
  2. Diagnose why Prometheus isn't scraping `netmetrics` — compare the
     annotated scrape port against the port the container actually listens
     on and serves `/metrics` on.
  3. Fix the annotation so Prometheus can reach `/metrics`.
  4. Generate real traffic against `netmetrics`'s `/hit` endpoint (through
     its Service, not by port-forwarding into the Pod directly) so
     `obs04_requests_total` is non-zero.
  5. Query Prometheus's HTTP API directly from inside the cluster to
     confirm the metric is now flowing:
     `kubectl run promql-check --image=busybox:1.36 --rm -it --restart=Never
     -- wget -qO- "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs04_requests_total"`
  6. Do the same for a built-in, always-present network-relevant metric,
     `apiserver_request_total`, to confirm Prometheus itself is healthy and
     was never the actual blocker.
  7. Do not modify the shared Prometheus server or its configuration — it
     is a cluster-wide resource used by every other lab.

Verification criteria:
  - The shared Prometheus server Deployment in `monitoring` is Ready
    (precondition, not something you are asked to change).
  - Deployment `netmetrics` in `ckne-obs-04` has `status.readyReplicas == 1`.
  - A request to `netmetrics`'s Service on port 8080 succeeds (Service
    traffic itself was never broken).
  - A PromQL query for `apiserver_request_total` against
    `prometheus-server.monitoring.svc.cluster.local` returns a real,
    non-empty, non-zero result.
  - A PromQL query for `obs04_requests_total` against the same endpoint
    returns a real, non-empty, non-zero result — proof Prometheus is now
    actually scraping `netmetrics`.
