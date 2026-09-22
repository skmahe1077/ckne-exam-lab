# CKNE Syllabus Mapping

Source syllabus: [Certified Kubernetes Network Engineer (CKNE)](https://training.linuxfoundation.org/certification/certified-kubernetes-network-engineer-ckne/)

This is the canonical lab matrix for this repository. Every lab directory
under `labs/<domain>/<task-id>/` must match a row below exactly: the
`Task ID`, `Namespace`, `Difficulty` and title are fixed here so that lab
content, `docs/coverage-gaps.md`, and the mock exams stay consistent.

Domain weights and lab counts (fixed by design brief):

| Domain                       | Weight | Labs |
| ----------------------------- | -----: | ---: |
| Core Infrastructure and CNI   |    15% |    6 |
| Service Networking and DNS    |    25% |   10 |
| Advanced Traffic Management   |    20% |    8 |
| Network Security and Policy   |    25% |   10 |
| Observability                 |    15% |    6 |
| **Total**                     |  100% |   40 |

Difficulty distribution (fixed by design brief): **8 beginner / 20 intermediate / 12 advanced**.

## Core Infrastructure and CNI (`labs/core-infrastructure-cni/`) — 6 labs

| Task ID | Namespace         | Difficulty   | Title                                              | Covers |
| ------- | ------------------ | ------------ | --------------------------------------------------- | ------ |
| CNI-01  | ckne-cni-01         | beginner     | Install and Configure Cilium CNI                     | CNI installation/config, Cilium |
| CNI-02  | ckne-cni-02         | beginner     | Pod CIDR and IPAM Allocation                         | IPAM, Pod CIDR |
| CNI-03  | ckne-cni-03         | intermediate | Linux Routing and iptables for Pod Traffic           | Linux routing, iptables, ip |
| CNI-04  | ckne-cni-04         | intermediate | Diagnosing Pod-to-Pod Connectivity                   | ss, tcpdump, pod-to-pod connectivity |
| CNI-05  | ckne-cni-05         | intermediate | DNS Troubleshooting at Node and Pod Level            | DNS troubleshooting |
| CNI-06  | ckne-cni-06         | advanced     | Multi-Interface Pods                                 | Multi-interface pods |

Difficulty: 2 beginner / 3 intermediate / 1 advanced.

## Service Networking and DNS (`labs/service-networking-dns/`) — 10 labs

| Task ID | Namespace   | Difficulty   | Title                                          | Covers |
| ------- | ----------- | ------------ | ------------------------------------------------ | ------ |
| SVC-01  | ckne-svc-01 | beginner     | ClusterIP Services and Selectors                 | ClusterIP, selectors, target ports |
| SVC-02  | ckne-svc-02 | beginner     | NodePort Services                                | NodePort, target ports |
| SVC-03  | ckne-svc-03 | intermediate | LoadBalancer Services                            | LoadBalancer |
| SVC-04  | ckne-svc-04 | intermediate | ExternalName Services                            | ExternalName |
| SVC-05  | ckne-svc-05 | intermediate | Headless Services and StatefulSet DNS            | Headless Services |
| SVC-06  | ckne-svc-06 | intermediate | EndpointSlices and Readiness                     | EndpointSlices, readiness |
| SVC-07  | ckne-svc-07 | intermediate | kube-proxy Modes and Behaviour                   | kube-proxy |
| SVC-08  | ckne-svc-08 | advanced     | CoreDNS Configuration and Forwarding             | CoreDNS, DNS forwarding |
| SVC-09  | ckne-svc-09 | advanced     | Gateway API: GatewayClass, Gateway, HTTPRoute    | GatewayClass, Gateway, HTTPRoute |
| SVC-10  | ckne-svc-10 | intermediate | Gateway API ReferenceGrant Across Namespaces     | ReferenceGrant |

Difficulty: 2 beginner / 6 intermediate / 2 advanced.

## Advanced Traffic Management (`labs/advanced-traffic-management/`) — 8 labs

| Task ID | Namespace   | Difficulty   | Title                                                  | Covers |
| ------- | ----------- | ------------ | -------------------------------------------------------- | ------ |
| ATM-01  | ckne-atm-01 | beginner     | Host- and Path-Based HTTPRoute Routing                    | Host routing, path routing |
| ATM-02  | ckne-atm-02 | intermediate | Header-Based Routing                                      | Header routing |
| ATM-03  | ckne-atm-03 | intermediate | Weighted Traffic Splitting (Canary)                       | Weighted traffic |
| ATM-04  | ckne-atm-04 | intermediate | Gateway TLS Termination                                    | Gateway TLS |
| ATM-05  | ckne-atm-05 | intermediate | Egress Gateway Traffic Control                             | Egress gateway |
| ATM-06  | ckne-atm-06 | advanced     | Cross-Cluster Service Discovery                            | Cross-cluster discovery |
| ATM-07  | ckne-atm-07 | advanced     | Cross-Cluster Load Balancing                               | Cross-cluster load balancing |
| ATM-08  | ckne-atm-08 | advanced     | Simulated LLM Traffic: Streaming, Timeouts, Retry Risks    | LLM traffic simulation, streaming, timeouts, retry risks |

Difficulty: 1 beginner / 4 intermediate / 3 advanced.

`ATM-08` never deploys a real LLM — it uses a lightweight app
(`shared/manifests/streaming-echo/`) that simulates delayed and
chunked/streaming HTTP responses.

## Network Security and Policy (`labs/network-security-policy/`) — 10 labs

| Task ID | Namespace   | Difficulty   | Title                                              | Covers |
| ------- | ----------- | ------------ | ----------------------------------------------------- | ------ |
| SEC-01  | ckne-sec-01 | beginner     | Default-Deny Ingress NetworkPolicy                    | Default-deny ingress |
| SEC-02  | ckne-sec-02 | beginner     | Default-Deny Egress NetworkPolicy                     | Default-deny egress |
| SEC-03  | ckne-sec-03 | intermediate | Pod-Selector NetworkPolicy                            | Pod selectors |
| SEC-04  | ckne-sec-04 | intermediate | Namespace-Selector NetworkPolicy                      | Namespace selectors |
| SEC-05  | ckne-sec-05 | intermediate | Combined Pod and Namespace Selectors                  | Combined selectors |
| SEC-06  | ckne-sec-06 | intermediate | IPBlock NetworkPolicy                                 | IP blocks |
| SEC-07  | ckne-sec-07 | intermediate | DNS Egress Control                                    | DNS egress |
| SEC-08  | ckne-sec-08 | advanced     | Cilium L3/L4/L7 Network Policy and Transparent Encryption | Cilium policy, node/pod encryption |
| SEC-09  | ckne-sec-09 | advanced     | TLS Certificates with cert-manager and ServiceAccount Identity | TLS, certificates, ServiceAccount identity |
| SEC-10  | ckne-sec-10 | advanced     | Istio mTLS and AuthorizationPolicy                    | Istio mTLS, AuthorizationPolicy |

Difficulty: 2 beginner / 5 intermediate / 3 advanced.

## Observability (`labs/observability/`) — 6 labs

| Task ID | Namespace   | Difficulty   | Title                                                       | Covers |
| ------- | ----------- | ------------ | -------------------------------------------------------------- | ------ |
| OBS-01  | ckne-obs-01 | beginner     | Kubernetes Events and Application Logs for Network Issues       | Events, application logs |
| OBS-02  | ckne-obs-02 | intermediate | CoreDNS Logs, Service and Endpoint Health                       | CoreDNS logs, service/endpoint health |
| OBS-03  | ckne-obs-03 | intermediate | Hubble Flows for Network Visibility                              | Hubble flows |
| OBS-04  | ckne-obs-04 | advanced     | Prometheus Metrics for Network Components                       | Prometheus metrics |
| OBS-05  | ckne-obs-05 | advanced     | Envoy Access Logs and Jaeger Distributed Tracing                 | Envoy logs, Jaeger traces |
| OBS-06  | ckne-obs-06 | advanced     | End-to-End Network Troubleshooting: Latency and Packet Loss      | Latency, packet loss, end-to-end troubleshooting |

Difficulty: 1 beginner / 2 intermediate / 3 advanced.

## Totals check

- Labs: 6 + 10 + 8 + 10 + 6 = **40**
- Difficulty: 8 beginner + 20 intermediate + 12 advanced = **40**
- All 40 Task IDs are unique by construction (`<DOMAIN-PREFIX>-<NN>`).

## Shared cluster-level add-ons (installed once, not per lab)

Cilium, Hubble, Gateway API CRDs + implementation, Istio, Prometheus,
Jaeger, cert-manager, Helm — see `kubeadm-setup/install-addons.sh` and
`docs/environment-versions.md`. Labs assume these are already installed;
labs that need a temporarily different cluster-wide configuration (e.g.
CoreDNS, Cilium policy mode) must use the locking mechanism in
`shared/scripts/lock.sh` (backed by a Lease in the `ckne-lab-system`
namespace) and restore the original configuration in `cleanup.sh`.
