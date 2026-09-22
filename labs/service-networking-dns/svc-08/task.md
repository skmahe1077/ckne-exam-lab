Task ID: SVC-08
Domain: Service Networking and DNS
Difficulty: advanced
Estimated time: 35 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-08

Scenario:
  The shared `kube-system/coredns` ConfigMap has an extra server block for
  the fictional test zone `svc08test.example.`, meant to forward those
  queries to a small self-hosted authoritative resolver (`test-dns` Service
  in `ckne-svc-08`) that answers `check.svc08test.example` with
  `10.99.99.99`. The block is misconfigured — its `forward` target does not
  point at that resolver — so lookups for the zone fail.

Objective:
  Fix ONLY the `svc08test.example` server block in the shared CoreDNS
  Corefile so it correctly forwards to the `test-dns` Service in your
  namespace, without touching or breaking anything else CoreDNS already
  does for the rest of the cluster.

Requirements:
  1. Find the `test-dns` Service's ClusterIP in `ckne-svc-08`.
  2. Edit `kube-system/coredns`'s `Corefile` (`kubectl -n kube-system get
     configmap coredns -o yaml`) and correct the `svc08test.example`
     block's `forward` target to that ClusterIP. Change nothing else in
     the Corefile — the rest of it (the `.` zone handling `cluster.local`
     and everything else) must remain exactly as it is.
  3. CoreDNS Pods need to pick up the change (the stock Corefile includes
     the `reload` plugin, which auto-detects ConfigMap changes within
     roughly a minute; you may instead `kubectl -n kube-system rollout
     restart deployment coredns` for an immediate reload).
  4. Confirm `check.svc08test.example` now resolves to `10.99.99.99` from
     an ordinary Pod using the cluster's normal DNS.
  5. Confirm normal in-cluster DNS (e.g.
     `kubernetes.default.svc.cluster.local`) still resolves — this is a
     shared, cluster-wide resource used by every other lab and namespace;
     you must not break it.

Verification criteria:
  - `kube-system/coredns`'s Corefile still contains its original
    `cluster.local` handling (the base config was extended, not replaced).
  - A DNS query for `check.svc08test.example` from a Pod resolves to
    `10.99.99.99`.
  - A DNS query for `kubernetes.default.svc.cluster.local` from a Pod
    still succeeds.
