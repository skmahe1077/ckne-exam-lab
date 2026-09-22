Task ID: OBS-06
Domain: Observability
Difficulty: advanced
Estimated time: 35 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-obs-06

Scenario:
  A `backend` app in `ckne-obs-06` genuinely takes about 3 seconds to answer
  any real request (it's not broken — that's just its normal processing
  time, exposed both as a `obs06_backend_delay_seconds` Prometheus metric
  and printed in its own logs on every request). A `client-config`
  ConfigMap holds `CLIENT_TIMEOUT_SECONDS`, which the persistent `client`
  Pod uses when requesting `backend`. Right now every request from `client`
  aborts before `backend` finishes — from the network's point of view this
  looks exactly like a dropped connection (the client sends a TCP RST and
  gives up), even though nothing was actually lost: the backend was still
  working the whole time.

Objective:
  Using Hubble flows, Prometheus's own latency metric, and backend's
  application logs together — not guesswork — determine that the backend's
  latency is real and legitimate, and that `client-config`'s timeout is
  simply too tight for it. Fix the timeout so end-to-end requests reliably
  succeed within a reasonable time.

Requirements:
  1. Do not modify the `backend` Deployment, its `DELAY_SECONDS` env var, or
     the `client` Pod — only `client-config`'s `CLIENT_TIMEOUT_SECONDS` may
     change.
  2. Use Hubble to observe the client → backend flow directly from a Cilium
     agent Pod (`kubectl -n kube-system exec <cilium-pod> -- hubble observe
     --namespace ckne-obs-06 --last 100`) — notice what happens to the
     connection when the client's timeout fires before backend responds.
  3. Query Prometheus for `obs06_backend_delay_seconds` to get backend's
     real, self-reported processing latency from actual telemetry, not a
     guess:
     `kubectl -n ckne-obs-06 exec client -c client -- wget -qO-
     "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs06_backend_delay_seconds"`
  4. Check backend's own application logs
     (`kubectl -n ckne-obs-06 logs deployment/backend --tail=50`) to confirm
     it really did process requests — just slower than the client was
     willing to wait.
  5. Fix `CLIENT_TIMEOUT_SECONDS` in `client-config` to a reasonable value:
     enough margin above backend's real latency to reliably succeed,
     without being an unreasonably large number that would just mask a
     real regression if backend ever got slower.
  6. Confirm a real, timed end-to-end request from `client` to `backend`
     now succeeds.

Verification criteria:
  - The Cilium DaemonSet (kube-system) and Prometheus server (monitoring)
    are Ready (preconditions, not something you are asked to change).
  - Deployment `backend` is `1/1` Ready and Pod `client` is `Running`.
  - `CLIENT_TIMEOUT_SECONDS` is a plain integer, at least 4 and at most 15.
  - A real, timed request from `client` to `backend` (using the configured
    timeout) succeeds and takes at least 2 seconds (proving it genuinely
    waited for backend's real processing time, not a fluke or a bypass).
  - `backend`'s own logs show it processed that specific request.
  - A PromQL query for `obs06_backend_delay_seconds` returns real,
    non-empty data.
  - Hubble flow data shows a `FORWARDED` flow between `client` and
    `backend`.
