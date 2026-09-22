Task ID: SVC-06
Domain: Service Networking and DNS
Difficulty: intermediate
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-06

Scenario:
  A `web` Deployment (2 replicas, nginx) and its `web` Service were deployed
  into `ckne-svc-06`, but the Service delivers no traffic. Both Pods show
  `Running` with `0/2` Ready.

Objective:
  Get both `web` Pods to `Ready`, confirm the `web` Service's EndpointSlice
  reflects them as usable endpoints, and confirm the Service routes traffic
  end-to-end again.

Requirements:
  1. Inspect the Pods' readiness status and probe output (`kubectl
     describe pod`, `kubectl get events`) to find out why they are not
     becoming Ready.
  2. Fix the readinessProbe configuration with the minimum change
     necessary — do not remove the probe, do not change the container
     image, do not modify the Service.
  3. Confirm the Deployment reaches `2/2` Ready.
  4. Inspect the actual EndpointSlice object(s) for the Service
     (`kubectl get endpointslice -n ckne-svc-06 -l
     kubernetes.io/service-name=web -o yaml`) and confirm both Pod
     addresses are listed with `conditions.ready: true`.
  5. Confirm the Service actually delivers traffic to the Pods.

Verification criteria:
  - Deployment `web` in `ckne-svc-06` has `status.readyReplicas == 2`.
  - The EndpointSlice(s) selecting Service `web` list exactly 2 endpoint
    addresses, all with `conditions.ready == true`.
  - A request to the `web` Service (`web.ckne-svc-06.svc.cluster.local`,
    port 80) succeeds end-to-end from another Pod in the cluster.
