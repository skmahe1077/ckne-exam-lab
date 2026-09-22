Task ID: SVC-07
Domain: Service Networking and DNS
Difficulty: intermediate
Estimated time: 25 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required — a
  privileged/hostNetwork debug Pod is used instead of SSH to inspect a
  node's iptables rules)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-07

Scenario:
  This cluster runs kube-proxy in `iptables` mode (see `kubectl -n
  kube-system get pods -l k8s-app=kube-proxy` and `kubectl -n kube-system
  get configmap kube-proxy -o yaml`). A `web` Deployment (2 replicas,
  nginx) already exists in `ckne-svc-07`, but it has no Service yet.

Objective:
  Create a ClusterIP Service exposing the `web` Deployment, then prove —
  by directly inspecting the node's iptables rules, not just by assuming —
  that kube-proxy actually programmed a path from the Service's ClusterIP
  to the backing Pods' IPs.

Requirements:
  1. Create a Service named `web` in `ckne-svc-07` that selects the
     existing `web` Pods and exposes port 80.
  2. kube-proxy's iptables rules live in the **node's root network
     namespace**, not inside an ordinary Pod's own network namespace — a
     normal Pod's `iptables-save` will show nothing about Services. To see
     the real rules, run a debug Pod with `hostNetwork: true` and the
     `NET_ADMIN`/`NET_RAW` capabilities added, then run `iptables-save`
     inside it.
  3. In that output, find the rule(s) that reference your Service's
     ClusterIP (`kubectl -n ckne-svc-07 get service web -o
     jsonpath='{.spec.clusterIP}'`) and identify the chain kube-proxy
     created for it (`KUBE-SVC-...`) and the per-Pod chains it jumps to
     (`KUBE-SEP-...`).
  4. Confirm the Service actually delivers traffic to the Pods end-to-end
     (a Service can exist and still be misconfigured — selector mismatch,
     wrong port — such that no working iptables path gets programmed).

Verification criteria:
  - Service `web` exists in `ckne-svc-07`, is type `ClusterIP`, selects the
    `web` Pods, and exposes port 80.
  - The Service's Endpoints/EndpointSlice list both `web` Pod IPs.
  - The node's iptables rules (inspected via a `hostNetwork` +
    `NET_ADMIN`/`NET_RAW` debug Pod) contain a rule referencing the
    Service's ClusterIP.
  - A request to the Service's ClusterIP on port 80 succeeds end-to-end.
