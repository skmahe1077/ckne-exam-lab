Task ID: SEC-10
Domain: Network Security and Policy
Difficulty: advanced
Estimated time: 40 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-sec-10

Scenario:
  `ckne-sec-10` is labeled `istio-injection: enabled`, and every Pod in it
  (including `backend`) has an `istio-proxy` sidecar. Right now `backend`
  has no `PeerAuthentication` or `AuthorizationPolicy` at all, so it accepts
  plaintext connections from anyone. Three caller Pods exist:
  `trusted-caller` (ServiceAccount `trusted-caller-sa` — the only identity
  that should ever reach `backend`), `untrusted-caller` (a different mesh
  identity, ServiceAccount `untrusted-caller-sa`, WITH a sidecar — a
  legitimate mesh member, just not one that should be allowed to call
  `backend`), and `no-mesh-caller` (explicitly opted OUT of sidecar
  injection via the `sidecar.istio.io/inject: "false"` annotation — a
  plaintext, non-mesh caller).

Objective:
  Require mutual TLS for all traffic to workloads in `ckne-sec-10`, and
  restrict `backend` so only the `trusted-caller-sa` identity may call it.

Requirements:
  1. Add a `PeerAuthentication` in `ckne-sec-10` (no workload `selector`,
     so it covers the whole namespace) with `mtls.mode: STRICT`.
  2. Add an `AuthorizationPolicy` in `ckne-sec-10` selecting `backend`
     (`selector: {matchLabels: {app: backend}}`), `action: ALLOW`, with a
     single rule whose `from.source.principals` contains exactly
     `cluster.local/ns/ckne-sec-10/sa/trusted-caller-sa`.
  3. Do not create either object in `istio-system` or with no namespace
     scoping — both must stay scoped to `ckne-sec-10` only.
  4. Do not modify `backend`, any caller Pod, or any ServiceAccount.
  5. `trusted-caller` must still be able to reach `backend`.
  6. `untrusted-caller` (has a sidecar, wrong identity) must be rejected.
  7. `no-mesh-caller` (no sidecar, plaintext) must be rejected.

Verification criteria:
  - `PeerAuthentication` exists in `ckne-sec-10` with `spec.mtls.mode ==
    STRICT`.
  - `AuthorizationPolicy` exists in `ckne-sec-10`, selecting `app: backend`,
    allowing only the `trusted-caller-sa` principal.
  - A request from `trusted-caller` to `backend` succeeds.
  - A request from `untrusted-caller` to `backend` fails (rejected by
    AuthorizationPolicy).
  - A request from `no-mesh-caller` to `backend` fails (rejected by STRICT
    mTLS — no sidecar means no client certificate to present).
