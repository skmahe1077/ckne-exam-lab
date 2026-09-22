Task ID: SVC-03
Domain: Service Networking and DNS
Difficulty: intermediate
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-03

Scenario:
  A `shop` Deployment (2 replicas, nginx) is running in the `ckne-svc-03`
  namespace with no Service in front of it yet. You need to expose it as a
  `type: LoadBalancer` Service.

  This cluster is a bare kubeadm cluster with no cloud provider integration
  (no AWS/GCP/Azure cloud-controller-manager, no MetalLB or similar
  bare-metal LoadBalancer controller installed). That means nothing will
  ever satisfy a `LoadBalancer` Service's request for an external IP —
  `status.loadBalancer.ingress` will stay empty and `kubectl get svc` will
  show `EXTERNAL-IP` as `<pending>` indefinitely. This is expected,
  correct behaviour for this environment, not a bug to fix. Your job is to
  configure the Service correctly and demonstrate you understand why it
  stays Pending, while also proving the Service still routes real traffic
  through its ClusterIP.

Objective:
  Create a `shop` Service of `type: LoadBalancer` that correctly selects
  the `shop` Deployment's Pods, and confirm it works end-to-end via its
  ClusterIP despite never receiving an external IP.

Requirements:
  1. Create a Service named `shop` in `ckne-svc-03` with `spec.type:
     LoadBalancer`, `spec.selector` matching the `shop` Deployment's Pods,
     and port 80 -> targetPort 80.
  2. Apply the required labels (`app.kubernetes.io/part-of: ckne-hands-on`,
     `ckne.openai.com/lab-id: "SVC-03"`) to the Service.
  3. Do not install or attempt to configure a LoadBalancer controller
     (MetalLB, cloud-controller-manager, etc.) — that is out of scope and
     would modify shared cluster state.
  4. Confirm the Service's `EXTERNAL-IP` remains `<pending>` and be able to
     explain why (no cloud provider integration in this cluster).
  5. Confirm the Service still routes traffic correctly via its ClusterIP
     (LoadBalancer Services always also get a ClusterIP and a nodePort;
     only the external LB provisioning step is unavailable here).

Verification criteria:
  - Service `shop` in `ckne-svc-03` exists with `spec.type == LoadBalancer`
    and a selector that gives it 2 healthy Endpoints.
  - Service `shop` has a valid `spec.clusterIP` assigned.
  - `status.loadBalancer.ingress` is empty/absent (Pending is the correct,
    expected state on this cluster — validate.sh checks for this, not for
    an external IP).
  - A request to the Service's ClusterIP on port 80 succeeds end-to-end
    from inside the cluster.
