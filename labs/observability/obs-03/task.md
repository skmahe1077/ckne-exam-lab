Task ID: OBS-03
Domain: Observability
Difficulty: intermediate
Estimated time: 25 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-obs-03

Scenario:
  A `web` Deployment/Service and two client Pods, `client-a` (labeled
  `role=allowed`) and `client-b` (labeled `role=blocked`), were deployed
  into the `ckne-obs-03` namespace along with a NetworkPolicy named
  `web-policy` that is supposed to allow only `role=allowed` Pods to reach
  `web` on port 80. Right now, traffic is backwards: `client-b` (which
  should be blocked) can reach `web`, and `client-a` (which should be
  allowed) cannot.

Objective:
  Fix `web-policy` so `client-a` is allowed and `client-b` is denied, then
  use Hubble — the cluster's shared, always-on eBPF flow observability layer
  — to directly observe both the allowed and the denied flow, proving the
  fix is correct at the network layer, not just "the Pod status looks
  right".

Requirements:
  1. Do not modify `client-a`, `client-b`, or the `web` Deployment/Service —
     only `web-policy`'s selector needs to change.
  2. Fix the NetworkPolicy so `client-a` (role=allowed) can reach `web` on
     port 80 and `client-b` (role=blocked) cannot.
  3. Query Hubble flow data directly from a Cilium agent Pod to confirm the
     fix at the network layer:
     `kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace
     ckne-obs-03 --last 100`
  4. In that output, identify the line(s) showing `client-a`'s request to
     `web` with verdict `FORWARDED`, and the line(s) showing `client-b`'s
     request to `web` with verdict `DROPPED`. A Cilium agent Pod only sees
     flows local to the node it runs on, so you may need to check more than
     one agent Pod (`kubectl -n kube-system get pods -l k8s-app=cilium -o
     wide`) depending on where `client-a`/`client-b`/`web` were scheduled.
  5. Do not touch the cluster-wide Cilium/Hubble installation itself — it is
     a shared resource used by every other lab.

Verification criteria:
  - The Cilium DaemonSet in `kube-system` is Ready on every node (precondition,
    not something you are asked to change).
  - Deployment `web` in `ckne-obs-03` has `status.readyReplicas == 1`.
  - `client-a` successfully reaches `web` over HTTP.
  - `client-b` is denied when it attempts to reach `web`.
  - Hubble flow data (queried from a Cilium agent Pod) shows a `FORWARDED`
    flow from `client-a` to `web`.
  - Hubble flow data shows a `DROPPED` flow from `client-b` to `web`.
