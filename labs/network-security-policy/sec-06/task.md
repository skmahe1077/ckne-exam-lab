Task ID: SEC-06
Domain: Network Security and Policy
Difficulty: intermediate
Estimated time: 25 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-sec-06

Scenario:
  A `backend` Deployment and Service are running in `ckne-sec-06`. Two probe
  Pods, `client-a` and `client-b`, were deliberately scheduled one per worker
  node (setup.sh recorded the exact node names and each node's Pod CIDR
  sub-range in a ConfigMap named `node-cidrs`). A `NetworkPolicy` named
  `restrict-backend-ingress` already exists, but it currently allows ingress
  to `backend` from the entire cluster Pod CIDR (10.244.0.0/16) — both
  `client-a` and `client-b` can reach it right now.

Objective:
  Pod IP addresses are dynamic and cannot be hardcoded into a policy ahead of
  time, but the Pod CIDR sub-range assigned to a given node is stable for as
  long as that node exists. Edit `restrict-backend-ingress` so that ingress
  to `backend` is still allowed from the cluster Pod CIDR in general, EXCEPT
  from the specific Pod CIDR sub-range assigned to the node `client-b` is
  running on — using a single `ipBlock` rule with a `cidr` and an `except`
  entry, not two separate rules.

Requirements:
  1. Read `kubectl -n ckne-sec-06 get configmap node-cidrs -o yaml` to find
     which node `client-a`/`client-b` are on and each node's actual Pod CIDR
     sub-range (`node-a-cidr`, `node-b-cidr`).
  2. Edit the existing `restrict-backend-ingress` NetworkPolicy's `ipBlock`
     rule so that its `cidr` remains `10.244.0.0/16` but it gains an
     `except` entry containing the value of `node-b-cidr`.
  3. Do not change the `podSelector`, do not add a second `ipBlock` entry,
     and do not touch `client-a`/`client-b`/`backend` themselves.
  4. After your fix, `client-a` must still be able to reach the `backend`
     Service; `client-b` must no longer be able to.

Verification criteria:
  - Deployment `backend` in `ckne-sec-06` is Ready.
  - A real HTTP request from `client-a` to `http://backend` succeeds.
  - A real HTTP request from `client-b` to `http://backend` fails/times out.
