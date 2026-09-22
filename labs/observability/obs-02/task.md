Task ID: OBS-02
Domain: Observability
Difficulty: intermediate
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-obs-02

Scenario:
  An `orders` Deployment (2 replicas, nginx) and its ClusterIP Service were
  deployed into the `ckne-obs-02` namespace. Every request to the `orders`
  Service fails. Someone on the team suspects CoreDNS is broken.

Objective:
  Use CoreDNS's own logs to rule DNS in or out, then correctly diagnose the
  actual Service/Endpoint health problem and fix it.

Requirements:
  1. Read the CoreDNS Pods' logs in `kube-system`
     (`kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100`) and look
     for any errors related to the `orders` Service or the `ckne-obs-02`
     namespace.
  2. Independently confirm whether DNS resolution of
     `orders.ckne-obs-02.svc.cluster.local` actually succeeds from inside
     the cluster (it does — a Service's DNS record exists as soon as the
     Service object exists, regardless of whether it has healthy backends).
  3. Having ruled out DNS, inspect the Service's Endpoints
     (`kubectl -n ckne-obs-02 get endpoints orders`) — are there any?
  4. Diagnose why the `orders` Pods are not contributing Endpoints
     (`kubectl -n ckne-obs-02 describe pod -l app=orders`, `kubectl -n
     ckne-obs-02 get pods`) — Running is not the same as Ready.
  5. Fix the actual root cause with the minimum change necessary. Do not
     modify CoreDNS — it was never the problem.
  6. The `orders` Service must route traffic to both Pods.

Verification criteria:
  - CoreDNS Deployment in `kube-system` is Ready (this must remain true —
    validate.sh checks it as a precondition, not as something you are asked
    to change).
  - Deployment `orders` in `ckne-obs-02` has `status.readyReplicas == 2`.
  - Service `orders`'s Endpoints list exactly 2 Pod IPs.
  - DNS resolution of `orders.ckne-obs-02.svc.cluster.local` succeeds from
    inside the cluster.
  - A request to the `orders` Service's ClusterIP on port 80 succeeds
    end-to-end.
