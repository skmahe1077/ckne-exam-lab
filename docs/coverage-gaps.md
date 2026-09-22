# Known Limitations and Coverage Gaps

Honest documentation of where this repository's single-cluster, AWS-CLI-only
environment can't fully replicate real-world or exam conditions, and how
each lab compensates.

- **No cloud LoadBalancer controller.** This is a bare kubeadm cluster with
  no cloud-provider integration, so a `type: LoadBalancer` Service's
  `status.loadBalancer.ingress` stays empty indefinitely. SVC-03 is written
  to teach and verify this correctly (configuring the Service properly and
  confirming it still works via ClusterIP/NodePort) rather than expecting a
  real external IP.

- **Only one real cluster exists** (1 control-plane + 2 workers). ATM-06
  (Cross-Cluster Service Discovery) and ATM-07 (Cross-Cluster Load
  Balancing) are scoped as Cilium Cluster Mesh **configuration and
  control-plane readiness** exercises against that single cluster, not
  tests of real cross-cluster traffic failover — see each lab's concept.md
  for the exact scope. A second cluster was deliberately not introduced via
  kind/k3s/MicroK8s/a second kubeadm cluster, per this repository's design
  constraints.

- **No Multus / multi-NIC CNI meta-plugin.** CNI-06 (Multi-Interface Pods)
  does not install Multus (out of scope for this repository's CNI choice).
  See CNI-06's concept.md for exactly what is and isn't simulated.

- **Jaeger runs all-in-one with in-memory storage** — traces do not survive
  a Jaeger Pod restart. Fine for a hands-on lab, not representative of a
  production tracing backend's durability.

- **Prometheus is the lightweight `prometheus-community/prometheus` chart**
  (server only), not the full `kube-prometheus-stack` — no Alertmanager, no
  Grafana, no persistent storage. OBS-04 works against whatever metrics are
  scraped by default from kube-state/Cilium/Istio endpoints; it does not
  assume Grafana dashboards exist.

- **No SSH by default.** Every lab is written to operate purely through
  `kubectl` against the cluster (no node shell access), consistent with
  `ENABLE_SSH=false` being the default in `cluster.env`. A small number of
  labs use a privileged/`hostNetwork` debug Pod instead of true node SSH
  where node-level state (e.g. iptables rules kube-proxy programmed) must be
  inspected — see each such lab's task.md for exactly what access it needs
  and why.

- **Gateway API `retry` is not usable in this cluster.** The `retry` field
  on `HTTPRoute` rules carries the `<gateway:experimental>` stability marker
  and only ships in the Gateway API *Experimental* CRD channel;
  `install-addons.sh` installs the *Standard* channel only
  (`standard-install.yaml`). ATM-08 therefore teaches the "blind retry
  against an already-slow backend compounds load" risk conceptually and
  demonstrates `HTTPRoute.spec.rules[].timeouts.request` (a Standard-channel
  field) instead of an actual retry policy.

- **`CiliumEgressGatewayPolicy` is cluster-scoped, not namespaced** (verified
  against Cilium's CRD definition: `scope: Cluster`). ATM-05 creates it with
  a lab-unique name (`ckne-atm-05-egress-policy`) and deletes it by that
  exact name in cleanup — the same "uniquely-named cluster-scoped resource
  needs no lock, only exact-name deletion" pattern used elsewhere (e.g.
  SEC-09's namespaced Issuer), not an oversight.

- **Two labs toggle real cluster-wide Cilium Helm values under the `cilium-config` lock**
  (ATM-05: `egressGateway.enabled`; SEC-08: `encryption.enabled`/`encryption.type`).
  Both revert the value and release the lock in `cleanup.sh`, and the lock
  guarantees they can't run concurrently — but a `helm upgrade --reuse-values`
  mid-flight failure (e.g. the student's shell killed between apply and
  revert) would leave the cluster-wide Cilium config changed until a human
  runs `make release-stale-lock` and manually reverts. This is an inherent
  risk of any lab that mutates a cluster singleton, not something the lock
  mechanism itself can fully eliminate.

- **This repository's authors did not have a live cluster to test lab
  content against end-to-end.** Every script was written to be structurally
  correct (`bash -n` clean, idempotent by design, following the shared
  `shared/scripts/lib.sh` conventions) but has not been exercised against a
  running AWS-provisioned cluster. See the root `README.md` "Validation
  results" section for exactly what was and wasn't verified.

This file should be updated as gaps are discovered during actual use —
please add to it rather than silently working around a limitation.
