Task ID: ATM-07
Domain: Advanced Traffic Management
Difficulty: advanced
Estimated time: 35 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-atm-07

SCOPE LIMITATION (read first):
  This environment has only one real Kubernetes cluster. This task is a
  configuration and control-plane readiness exercise for Cilium Cluster
  Mesh's cross-cluster load-balancing affinity — it does NOT connect a
  second cluster and does NOT test actual traffic being distributed between
  clusters. You are exercising exactly the parts that are testable with one
  cluster: the control-plane component and the per-Service affinity
  configuration. See concept.md for the full reasoning.

Scenario:
  Cilium Cluster Mesh's control-plane component, `clustermesh-apiserver`,
  has already been deployed into `kube-system` (a precondition of this lab,
  not something you need to change) along with its generated mTLS
  certificates. A `pricing` Deployment and Service are running in
  `ckne-atm-07`. The Service is already correctly marked as a Cluster Mesh
  global, shared service (`service.cilium.io/global` and
  `service.cilium.io/shared` are both `"true"` — a precondition, not the
  task) — but its cross-cluster load-balancing affinity is set to `"remote"`,
  the opposite of what the platform team requires: pricing lookups must stay
  in the local cluster whenever possible, and only fail over to a remote
  cluster's backends if every local backend becomes unhealthy.

Objective:
  Confirm the `clustermesh-apiserver` control plane is healthy, then
  correct the `pricing` Service's cross-cluster affinity so it prefers local
  backends and only fails over to remote ones when local is unhealthy.

Requirements:
  1. Do not modify the `pricing` Deployment — it is already correct.
  2. Do not modify `clustermesh-apiserver` or its Secrets — they are a
     precondition, already correctly deployed.
  3. Do not change `service.cilium.io/global` or `service.cilium.io/shared`
     — they are already correct.
  4. Correct the `service.cilium.io/affinity` annotation so it expresses
     "prefer local backends, fail over to remote only if local is
     unhealthy."

Verification criteria:
  - The Cilium DaemonSet in kube-system is Ready on every node (precondition,
    not something you are asked to change).
  - `clustermesh-apiserver` in kube-system has a Ready Deployment and an
    existing Service (precondition, not something you are asked to change).
  - The four `clustermesh-apiserver-*-cert` Secrets in kube-system each
    contain non-empty `tls.crt`, `tls.key`, and `ca.crt` data (precondition,
    not something you are asked to change).
  - Deployment `pricing` in `ckne-atm-07` is Ready.
  - Service `pricing` still carries `service.cilium.io/global: "true"` and
    `service.cilium.io/shared: "true"` (unchanged).
  - Service `pricing` carries `service.cilium.io/affinity: "local"`.
