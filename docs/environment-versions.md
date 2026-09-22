# Environment Versions

Pinned versions installed by `kubeadm-setup/common.sh` and
`kubeadm-setup/install-addons.sh`. Bump these deliberately (search the
corresponding script for the version string) rather than letting anything
float to "latest" — labs are written against specific, known-good behavior.

| Component            | Version           | Installed by |
| --------------------- | ------------------ | ------------ |
| OS                     | Ubuntu 24.04 LTS (discovered via SSM public parameter, no hard-coded AMI) | `aws-infra-setup.sh` |
| Kubernetes             | v1.35.x (exact patch discovered from the apt repo at install time) | `common.sh` |
| containerd             | 2.2.0               | `common.sh` |
| runc                   | 1.3.3               | `common.sh` |
| crictl                 | v1.35.0             | `common.sh` |
| Cilium (CNI + Gateway API impl. + Hubble) | 1.16.5 (Helm chart) | `install-addons.sh` |
| Gateway API CRDs       | v1.2.1 (standard channel) | `install-addons.sh` |
| Istio (base + istiod)  | 1.24.2 (Helm chart) | `install-addons.sh` |
| Prometheus             | chart `prometheus-community/prometheus` 25.27.0 | `install-addons.sh` |
| Jaeger                 | chart `jaegertracing/jaeger` 3.4.1, all-in-one, in-memory storage | `install-addons.sh` |
| cert-manager           | v1.16.2 (Helm chart, CRDs included) | `install-addons.sh` |
| Helm                   | latest 3.x at install time (official get-helm-3 script) | `install-addons.sh` |

## Notes on choices

- **Prometheus** is installed via the lightweight `prometheus-community/prometheus`
  chart (server only — no Alertmanager, no Pushgateway, no persistent
  volume) rather than the much heavier `kube-prometheus-stack`, to keep
  resource usage reasonable on `t3.large` nodes. It still scrapes
  cluster/Cilium/Istio metrics for the Observability domain labs.
- **Jaeger** runs `allInOne` with in-memory storage — traces do not survive
  a Pod restart, which is fine for a hands-on lab environment and avoids
  standing up Cassandra/Elasticsearch.
- **Cilium is the cluster's Gateway API implementation** (`gatewayAPI.enabled=true`)
  — no separate Gateway controller (e.g. Envoy Gateway) is installed. This
  keeps the CNI and the Gateway data plane on one code path, which is also
  what SVC-07 through SVC-09 and the Advanced Traffic Management labs
  assume.
- **kube-proxy stays enabled** (`kubeProxyReplacement=false` in the Cilium
  Helm values) specifically so SVC-07 (kube-proxy modes and behaviour) has
  something real to inspect. If you later want a kube-proxy-free cluster for
  your own purposes, flipping this is a cluster-wide, locked change (see
  `shared/scripts/lock.sh`) — not something any lab does automatically.
- A shared `GatewayClass` named `cilium` is created once by
  `install-addons.sh` (in the `cilium` and `gateway-api` component blocks).
  Labs must reference this GatewayClass by name — never create their own
  GatewayClass — since it is a cluster-scoped singleton.
