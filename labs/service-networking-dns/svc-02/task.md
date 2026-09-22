Task ID: SVC-02
Domain: Service Networking and DNS
Difficulty: beginner
Estimated time: 15 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-02

Scenario:
  A `web` Deployment (2 replicas, nginx) and a `web` NodePort Service were
  deployed into the `ckne-svc-02` namespace. `kubectl get svc` shows the
  Service has a `nodePort` assigned in the 30000-32767 range, and
  `kubectl get endpoints` shows Pod IPs — but requests through the Service
  still fail.

  Note: this cluster's security group only allows inbound traffic on the
  NodePort range (30000-32767) from within the cluster's own network, not
  from the internet. That is expected and is not the bug you're looking
  for — test from inside the cluster.

Objective:
  Find why traffic through the NodePort Service isn't reaching the `web`
  Pods, and fix it.

Requirements:
  1. Confirm the `web` Deployment is 2/2 Ready and the Service has healthy
     Endpoints (both already true — the problem is elsewhere).
  2. Confirm the Service's `type` is `NodePort` and it has a `nodePort`
     allocated in the 30000-32767 range (already true).
  3. Inspect the Service's `targetPort` against the port the `web`
     container actually listens on.
  4. Fix the Service (minimum change necessary) so traffic sent to a
     node's IP on the allocated nodePort actually reaches a Pod.

Verification criteria:
  - Service `web` in `ckne-svc-02` has `spec.type == NodePort` with
    `spec.ports[0].nodePort` inside 30000-32767.
  - Service `web`'s Endpoints list 2 healthy Pod IPs.
  - A request sent to `<any-node-IP>:<nodePort>` from inside the cluster
    succeeds end-to-end and returns a response from nginx.
