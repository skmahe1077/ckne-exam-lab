Task ID: ATM-06
Domain: Advanced Traffic Management
Difficulty: advanced
Estimated time: 35 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-atm-06

SCOPE LIMITATION (read first):
  This environment has only one real Kubernetes cluster. This task is a
  configuration and control-plane readiness exercise for Cilium Cluster
  Mesh — it does NOT connect a second cluster and does NOT test actual
  cross-cluster traffic or failover. You are exercising exactly the parts of
  Cluster Mesh that are testable with one cluster: the control-plane
  component and the per-Service opt-in configuration. See concept.md for the
  full reasoning.

Scenario:
  Cilium Cluster Mesh's control-plane component, `clustermesh-apiserver`,
  has already been deployed into `kube-system` (a precondition of this lab,
  not something you need to change) along with its generated mTLS
  certificates. A `catalog` Deployment and Service are running in
  `ckne-atm-06`, serving traffic normally within this cluster — but the
  Service has not been configured as a Cluster Mesh global service, so if a
  second cluster were ever connected to this one, `catalog` would never be
  discovered from it.

Objective:
  Confirm the `clustermesh-apiserver` control plane is healthy, then
  configure the `catalog` Service so it is correctly marked for
  cross-cluster discovery.

Requirements:
  1. Do not modify the `catalog` Deployment — it is already correct.
  2. Do not modify `clustermesh-apiserver` or its Secrets — they are a
     precondition, already correctly deployed.
  3. Add the annotation that marks `catalog` as a Cluster Mesh global
     service, so that in a real multi-cluster mesh it would be discovered
     and load-balanced to from any connected remote cluster.
  4. Do not change the Service's selector, ports, or type — only its
     annotations need to change.

Verification criteria:
  - The Cilium DaemonSet in kube-system is Ready on every node (precondition,
    not something you are asked to change).
  - `clustermesh-apiserver` in kube-system has a Ready Deployment and an
    existing Service (precondition, not something you are asked to change).
  - The four `clustermesh-apiserver-*-cert` Secrets in kube-system each
    contain non-empty `tls.crt`, `tls.key`, and `ca.crt` data (precondition,
    not something you are asked to change).
  - Deployment `catalog` in `ckne-atm-06` is Ready.
  - Service `catalog` carries the annotation
    `service.cilium.io/global: "true"`.
