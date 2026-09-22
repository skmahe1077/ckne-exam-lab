Task ID: SEC-02
Domain: Network Security and Policy
Difficulty: beginner
Estimated time: 25 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-sec-02

Scenario:
  A `client` Pod, and two identical nginx targets — `allowed-target`
  (Service `allowed-svc`) and `blocked-target` (Service `blocked-svc`) — run
  in `ckne-sec-02`. A `default-deny-egress` NetworkPolicy already selects
  `client` and blocks ALL of its outbound traffic, including DNS lookups to
  CoreDNS. `client` is supposed to be able to reach `allowed-svc` (and
  resolve names via DNS), but never `blocked-svc`.

Objective:
  Without removing or replacing `default-deny-egress`, add the minimum
  egress-allow configuration so `client` can (a) resolve DNS via CoreDNS and
  (b) reach `allowed-target` on port 80 — while `blocked-target` remains
  unreachable.

Requirements:
  1. Leave the `default-deny-egress` NetworkPolicy in place and unmodified.
  2. Add egress-allow rule(s) permitting `client` to reach CoreDNS in
     `kube-system` (UDP and TCP port 53) — default-deny egress blocks DNS
     too, it is not a special case.
  3. Add an egress-allow rule permitting `client` to reach `allowed-target`
     Pods specifically, on TCP port 80.
  4. `client` must NOT be able to reach `blocked-target` at all.

Verification criteria:
  - `default-deny-egress` still exists with `policyTypes: [Egress]`.
  - `client` can resolve `allowed-svc.ckne-sec-02.svc.cluster.local` via DNS.
  - A request from `client` to `allowed-svc` succeeds within a 5-second
    timeout.
  - A request from `client` to `blocked-svc` fails/times out.
