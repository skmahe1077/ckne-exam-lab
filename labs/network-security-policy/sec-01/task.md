Task ID: SEC-01
Domain: Network Security and Policy
Difficulty: beginner
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-sec-01

Scenario:
  A `backend` Deployment (nginx) and Service are running in `ckne-sec-01`,
  alongside two client Pods: `client-frontend` (labeled `role: frontend`) and
  `client-other` (labeled `role: other`). A `default-deny-ingress`
  NetworkPolicy already selects every Pod in the namespace and blocks ALL
  ingress traffic — including from `client-frontend`, which is supposed to
  be allowed to reach `backend`.

Objective:
  Without removing or replacing the existing `default-deny-ingress` policy,
  add the minimum NetworkPolicy configuration needed so that ONLY Pods
  labeled `role: frontend` can reach `backend` on port 80. `client-other`
  must remain blocked.

Requirements:
  1. Leave the `default-deny-ingress` NetworkPolicy in place and unmodified.
  2. Add a NetworkPolicy (new object, or an edit that preserves the deny
     policy's effect) that permits ingress to Pods labeled `app: backend`
     only from Pods labeled `role: frontend`, on TCP port 80.
  3. `client-frontend` must be able to reach `http://backend` successfully.
  4. `client-other` must remain unable to reach `backend` at all.

Verification criteria:
  - `default-deny-ingress` still exists with `policyTypes: [Ingress]` and no
    Pods other than `role: frontend` are able to reach `backend`.
  - A request from `client-frontend` to the `backend` Service succeeds
    end-to-end within a 5-second timeout.
  - A request from `client-other` to the `backend` Service fails/times out.
