Task ID: SEC-04
Domain: Network Security and Policy
Difficulty: intermediate
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-sec-04 (plus a second namespace this lab owns: ckne-sec-04-clients)

Scenario:
  A `backend` Deployment/Service in `ckne-sec-04` currently has no
  NetworkPolicy at all, so any Pod from any namespace can reach it —
  including `untrusted-client`, which lives right there in `ckne-sec-04`
  itself. A second namespace, `ckne-sec-04-clients`, is labeled
  `network-access: trusted` and contains `client-a`, which is supposed to
  be allowed to reach `backend`.

Objective:
  Restrict ingress to `backend` so that only Pods running in namespaces
  labeled `network-access: trusted` can reach it — regardless of any label
  on the Pod itself, and regardless of which namespace the Pod is
  physically "close to".

Requirements:
  1. Add a NetworkPolicy in `ckne-sec-04` that allows ingress to `backend`
     (TCP port 80) only from Pods in namespaces matching
     `namespaceSelector: {matchLabels: {network-access: trusted}}`.
  2. Do not add a `podSelector` on the `from` side — this must be a
     pure namespace-selector rule.
  3. Do not modify the `network-access: trusted` label on
     `ckne-sec-04-clients`, or create/label any other namespace.
  4. `client-a` (in `ckne-sec-04-clients`) must be able to reach `backend`.
  5. `untrusted-client` (in `ckne-sec-04` itself, an untrusted namespace)
     must remain blocked.

Verification criteria:
  - Deployment `backend` is Ready.
  - `ckne-sec-04-clients` still carries `network-access=trusted`.
  - A request from `client-a` to `backend` succeeds within 5 seconds.
  - A request from `untrusted-client` to `backend` fails/times out.
