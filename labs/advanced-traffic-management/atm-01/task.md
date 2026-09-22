Task ID: ATM-01
Domain: Advanced Traffic Management
Difficulty: beginner
Estimated time: 20 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-atm-01

Scenario:
  Two independent backends, `blue` and `green`, are running in the
  `ckne-atm-01` namespace, each behind its own Service, fronted by a single
  Gateway (`atm-gw`, using the cluster's shared `cilium` GatewayClass). Two
  HTTPRoute objects were written to route traffic to them — one by
  hostname, one by path — but someone swapped things around: requests for
  `blue.ckne.local` currently reach the `green` backend (and vice versa),
  and requests to `/blue` currently reach `green` (and vice versa).

Objective:
  Fix the HTTPRoute objects `host-routes`, `host-routes-green`, and
  `path-routes` in `ckne-atm-01` so that host-based and path-based routing
  both send traffic to the correct backend.

Requirements:
  1. A request with `Host: blue.ckne.local` must be routed to the `blue`
     backend.
  2. A request with `Host: green.ckne.local` must be routed to the `green`
     backend.
  3. A request to `Host: app.ckne.local`, path `/blue`, must be routed to
     the `blue` backend.
  4. A request to `Host: app.ckne.local`, path `/green`, must be routed to
     the `green` backend.
  5. Do not modify the Gateway, the backend Deployments/Services, or the
     GatewayClass — only the HTTPRoute objects need to change.

Verification criteria:
  - The shared GatewayClass `cilium` is Accepted (precondition, not
    something you are asked to change).
  - Gateway `atm-gw` in `ckne-atm-01` reports condition `Programmed=True`.
  - A real HTTP request with `Host: blue.ckne.local` against the Gateway
    returns a body containing `blue-backend`.
  - A real HTTP request with `Host: green.ckne.local` against the Gateway
    returns a body containing `green-backend`.
  - A real HTTP request with `Host: app.ckne.local` and path `/blue`
    returns a body containing `blue-backend`.
  - A real HTTP request with `Host: app.ckne.local` and path `/green`
    returns a body containing `green-backend`.
