Task ID: ATM-02
Domain: Advanced Traffic Management
Difficulty: intermediate
Estimated time: 25 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-atm-02

Scenario:
  Two independent backends, `stable` and `canary`, are running in the
  `ckne-atm-02` namespace, each behind its own Service, fronted by a single
  Gateway (`atm-gw`, using the cluster's shared `cilium` GatewayClass). The
  existing HTTPRoute `header-routes` sends every request to `stable`. The
  team wants to be able to opt individual requests into the canary build by
  sending a custom request header, without touching DNS or deploying a
  second hostname.

Objective:
  Add a header-based routing rule to the `header-routes` HTTPRoute in
  `ckne-atm-02` so that any request carrying the header `X-Canary: true`
  is routed to the `canary` backend, while every other request (including
  one with `X-Canary` set to anything other than `true`, or no `X-Canary`
  header at all) keeps reaching `stable`.

Requirements:
  1. Requests with header `X-Canary: true` must be routed to the `canary`
     backend.
  2. Requests without an `X-Canary` header must be routed to the `stable`
     backend.
  3. Requests with `X-Canary` set to any value other than exactly `true`
     must also be routed to the `stable` backend.
  4. Do not modify the Gateway, the backend Deployments/Services, or the
     GatewayClass — only the HTTPRoute needs to change.
  5. Do not create a second HTTPRoute or a second hostname — the header
     match must live inside `header-routes`.

Verification criteria:
  - The shared GatewayClass `cilium` is Accepted (precondition, not
    something you are asked to change).
  - Gateway `atm-gw` in `ckne-atm-02` reports condition `Programmed=True`.
  - A real HTTP request with no `X-Canary` header returns a body
    containing `stable-backend`.
  - A real HTTP request with `X-Canary: true` returns a body containing
    `canary-backend`.
  - A real HTTP request with `X-Canary: false` returns a body containing
    `stable-backend` (proves the match is an exact-value match, not "header
    present").
