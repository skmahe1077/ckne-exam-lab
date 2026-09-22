Task ID: SVC-09
Domain: Service Networking and DNS
Difficulty: advanced
Estimated time: 30 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-09

Scenario:
  A `web` Deployment and ClusterIP Service are running in `ckne-svc-09`,
  serving distinct, identifiable content. The cluster already has a shared,
  cluster-wide Gateway API `GatewayClass` named `cilium`
  (`controllerName: io.cilium/gateway-controller`), installed once by
  `kubeadm-setup/install-addons.sh` — but no `Gateway` or `HTTPRoute`
  exists yet in `ckne-svc-09`, so `web` is unreachable from outside its own
  ClusterIP.

Objective:
  Author a `Gateway` and an `HTTPRoute` in `ckne-svc-09` from scratch that
  together expose `web` over HTTP, referencing the shared `GatewayClass`
  by name only.

Requirements:
  1. Do not create, edit, or delete the `GatewayClass` named `cilium` — it
     is a shared, cluster-wide resource used by every other lab. Reference
     it by name only: `gatewayClassName: cilium`.
  2. Do not modify the `web` Deployment, Service, or ConfigMap.
  3. Create a `Gateway` in `ckne-svc-09` with a single HTTP listener on
     port 80, restricted to `HTTPRoute`s in the same namespace
     (`allowedRoutes.namespaces.from: Same`).
  4. Create an `HTTPRoute` that attaches to your `Gateway` (via
     `parentRefs`) and routes requests to the `web` Service on port 80.
  5. Confirm your `Gateway` reports `status.conditions[type=Programmed]
     == True`.
  6. Confirm a real HTTP request through the Gateway (not the Service
     directly) reaches `web` and returns its content.

Verification criteria:
  - The shared `GatewayClass` `cilium` is `Accepted` (precondition, not
    something you are asked to change).
  - Deployment `web` in `ckne-svc-09` remains `1/1` Ready.
  - A `Gateway` using `gatewayClassName: cilium` exists in `ckne-svc-09`
    and reports `Programmed=True`.
  - A real HTTP request sent to the Gateway's auto-created ClusterIP
    Service (`cilium-gateway-<your-gateway-name>`) on port 80 returns a
    body containing `svc09-backend`.
