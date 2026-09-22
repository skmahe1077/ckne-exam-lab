Task ID: SEC-05
Domain: Network Security and Policy
Difficulty: intermediate
Estimated time: 25 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-sec-05 (plus a second namespace this lab owns: ckne-sec-05-clients)

Scenario:
  A `backend` Deployment/Service in `ckne-sec-05` currently has no
  `NetworkPolicy` at all. `ckne-sec-05-clients` is labeled `team: payments`
  and contains two Pods: `frontend-a` (labeled `role: frontend`) and
  `worker-a` (labeled `role: worker` — same trusted namespace, different
  role). `ckne-sec-05` itself (backend's own, untrusted namespace) also
  contains `rogue-frontend`, a Pod that carries `role: frontend` even though
  it does not live in the trusted namespace.

Objective:
  Restrict ingress to `backend` so that only Pods which are **both** (a) in
  a namespace labeled `team: payments` **and** (b) carrying the Pod label
  `role: frontend` can reach it. Neither condition alone is sufficient.

Requirements:
  1. Add a `NetworkPolicy` in `ckne-sec-05` that allows ingress to `backend`
     (TCP port 80) only from Pods matching BOTH `namespaceSelector:
     {matchLabels: {team: payments}}` AND `podSelector: {matchLabels: {role:
     frontend}}` combined as a single AND condition (one `from` list
     element carrying both selectors) — not as two separate `from` list
     elements (which would mean OR, not AND).
  2. Do not modify the `team: payments` label on `ckne-sec-05-clients`, the
     `role` labels on `frontend-a`/`worker-a`/`rogue-frontend`, or create/
     label any other namespace.
  3. `frontend-a` (trusted namespace + correct role) must be able to reach
     `backend`.
  4. `worker-a` (trusted namespace, wrong role) must remain blocked.
  5. `rogue-frontend` (correct role, untrusted namespace) must remain
     blocked.

Verification criteria:
  - Deployment `backend` is Ready.
  - `ckne-sec-05-clients` still carries `team=payments`.
  - A request from `frontend-a` to `backend` succeeds within 5 seconds.
  - A request from `worker-a` to `backend` fails/times out.
  - A request from `rogue-frontend` to `backend` fails/times out.
