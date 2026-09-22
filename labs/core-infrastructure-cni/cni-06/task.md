Task ID: CNI-06
Domain: Core Infrastructure and CNI
Difficulty: advanced
Estimated time: 35 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-cni-06

Scenario:
  This cluster does not have Multus installed, so genuine secondary-NIC
  "multi-interface Pod" attachment is not available. A `multi-iface-app`
  Pod has already been deployed to simulate the pattern instead: it runs
  two containers in the same Pod, `data-plane` (HTTP on port 8080) and
  `mgmt-plane` (HTTP on port 9090), standing in for what would otherwise be
  two separately-attached NICs. Two Services, `data-svc` and `mgmt-svc`,
  each front one of those ports. Two client Pods already exist:
  `client` (an ordinary workload, no special label) and `admin-client`
  (labeled `role: admin`). Right now there is no `NetworkPolicy` at all, so
  both client Pods can reach both `data-svc` and `mgmt-svc` — the management
  plane is not actually restricted to admins.

Objective:
  First, confirm directly that this Pod has only one real network interface
  (one `podIP`) despite exposing two logical "interfaces" via its two
  containers/ports — do not assume this, check it. Then add a
  `NetworkPolicy` that enforces per-interface ingress rules: the data plane
  (port 8080) must stay reachable from any Pod in the namespace, but the
  management plane (port 9090) must become reachable only from Pods labeled
  `role: admin`.

Requirements:
  1. Inspect `multi-iface-app`'s Pod spec/status and confirm it has exactly
     one entry in `status.podIPs` (a single real interface) even though it
     serves two logical interfaces via its two containers.
  2. Add a `NetworkPolicy` in `ckne-cni-06` selecting `multi-iface-app`'s
     Pods, with `Ingress` in `policyTypes`.
  3. Port 8080 (`data-plane`) must remain reachable from any Pod in
     `ckne-cni-06` (do not restrict it by `podSelector`).
  4. Port 9090 (`mgmt-plane`) must be reachable only from Pods carrying the
     label `role: admin`.
  5. Do not add a second container, a second Pod IP, or any Multus-related
     object — this task is solved entirely with a `NetworkPolicy`.
  6. Do not modify the `client` or `admin-client` Pods or their labels.

Verification criteria:
  - Deployment `multi-iface-app` is Ready (both containers Ready).
  - The Pod has exactly one `podIP`.
  - `client` (no special label) can reach `data-svc:8080` successfully.
  - `client` cannot reach `mgmt-svc:9090` (blocked).
  - `admin-client` (`role: admin`) can reach `mgmt-svc:9090` successfully.
  - `admin-client` can also reach `data-svc:8080` successfully.
