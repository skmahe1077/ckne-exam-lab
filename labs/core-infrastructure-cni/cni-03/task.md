Task ID: CNI-03
Domain: Core Infrastructure and CNI
Difficulty: intermediate
Estimated time: 30 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: a NET_ADMIN-capable debug Pod (`toolbox`) in the cluster; kubectl exec
  is used to run commands inside its own network namespace — no node SSH
  required and no node-level state is touched.
Context: default (uses your current kubeconfig context)
Namespace: ckne-cni-03

Scenario:
  A `server` Deployment (nginx) is running and Ready in `ckne-cni-03`. A
  Pod named `toolbox` (image `nicolaka/netshoot`, granted `NET_ADMIN` /
  `NET_RAW`) is also Running and Ready — but every attempt to reach
  `server` on port 80 from inside `toolbox` times out.

Objective:
  Using only tools available inside the `toolbox` Pod (`ip`, `iptables`),
  diagnose why its own outbound traffic to tcp/80 never leaves it, and fix
  it — entirely within `toolbox`'s own network namespace. Do not modify
  anything on the underlying nodes.

Requirements:
  1. Confirm basic routing inside `toolbox` looks sane
     (`kubectl exec toolbox -- ip addr`, `ip route`) — rule out an
     interface/routing problem before looking elsewhere.
  2. Inspect `toolbox`'s own iptables rules
     (`kubectl exec toolbox -- iptables -L -n -v --line-numbers`) and find
     the rule responsible for silently dropping its outbound tcp/80
     traffic.
  3. Remove only that rule — the minimum change necessary. Do not flush
     all chains, and do not touch anything outside the `toolbox` Pod (no
     node-level iptables, no other Pod's netns).
  4. Confirm `toolbox` can now reach `server` on port 80.

Verification criteria:
  - Deployment `server` is 1/1 Ready.
  - Pod `toolbox` is Running.
  - `toolbox`'s iptables `OUTPUT` chain no longer drops outbound tcp/80.
  - A request from inside `toolbox` to `server`'s ClusterIP on port 80
    succeeds (HTTP 200).
