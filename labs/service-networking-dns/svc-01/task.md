Task ID: SVC-01
Domain: Service Networking and DNS
Difficulty: beginner
Estimated time: 15 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-01

Scenario:
  An `api` Deployment (2 replicas, nginx) and an `api` ClusterIP Service were
  deployed into the `ckne-svc-01` namespace. The Deployment's Pods are
  2/2 Ready, but nothing reaches them through the Service — every request
  times out.

Objective:
  Determine why the Service isn't routing traffic to the `api` Deployment's
  Pods, and fix it so the Service actually delivers requests to them.

Requirements:
  1. Confirm the `api` Deployment is 2/2 Ready (it already is — the problem
     is not the Pods).
  2. Inspect the Service's Endpoints/EndpointSlices to see whether it has
     picked up any Pod backends at all.
  3. Compare the Service's `spec.selector` against the actual labels on the
     Deployment's Pods.
  4. Fix the Service (minimum change necessary) so it selects the `api`
     Pods correctly.
  5. Do not change the Deployment's Pod labels — fix the Service.

Verification criteria:
  - Deployment `api` in `ckne-svc-01` has `status.readyReplicas == 2`
    (unchanged precondition).
  - Service `api`'s Endpoints/EndpointSlices list exactly 2 Pod IPs.
  - A request to the `api` Service's ClusterIP on port 80 succeeds
    end-to-end from inside the cluster (not just "Service exists" or
    "Endpoints non-empty").
