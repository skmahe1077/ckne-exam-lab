Task ID: CNI-01
Domain: Core Infrastructure and CNI
Difficulty: beginner
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-cni-01

Scenario:
  A `web` Deployment (2 replicas, nginx) and its Service were deployed into
  the `ckne-cni-01` namespace, but the Deployment shows 0/2 Ready. Someone on
  the team suspects the Cilium CNI installation is broken.

Objective:
  Determine whether Cilium is actually the cause, and get the `web`
  Deployment to 2/2 Ready with the Service routing traffic to both Pods.

Requirements:
  1. Check the health of the cluster's Cilium installation (DaemonSet status
     across all nodes in kube-system) and record what you find.
  2. Diagnose why the `web` Deployment's Pods are not becoming Ready — use
     `kubectl describe`/`kubectl get events` on the Pods, not guesswork.
  3. Fix the actual root cause with the minimum change necessary. Do not
     modify the Cilium installation itself — it is a shared, cluster-level
     resource used by every other lab.
  4. `web` must reach `2/2` Ready, and the `web` Service (ClusterIP) must
     successfully route to both Pods.

Verification criteria:
  - The Cilium DaemonSet in kube-system is Ready on every node (this must
    remain true — validate.sh checks it as a precondition, not as something
    you are asked to change).
  - Deployment `web` in `ckne-cni-01` has `status.readyReplicas == 2`.
  - Both `web` Pods have a PodIP inside the cluster's configured Pod CIDR
    (10.244.0.0/16).
  - A request to the `web` Service's ClusterIP on port 80 succeeds
    end-to-end (not just "Service exists").
