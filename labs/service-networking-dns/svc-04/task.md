Task ID: SVC-04
Domain: Service Networking and DNS
Difficulty: intermediate
Estimated time: 15 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-svc-04

Scenario:
  An `ExternalName` Service named `docs` was deployed into the `ckne-svc-04`
  namespace, intended to give in-cluster Pods a stable internal DNS name
  (`docs.ckne-svc-04.svc.cluster.local`) that resolves out to a real
  external site. Right now, looking it up from inside the cluster returns
  NXDOMAIN — it resolves nowhere.

Objective:
  Fix the Service so that resolving
  `docs.ckne-svc-04.svc.cluster.local` from inside the cluster correctly
  returns a CNAME to a real, resolvable external DNS name.

Requirements:
  1. Inspect the Service's `spec.externalName` field.
  2. Confirm (from a Pod inside the cluster, e.g. with `nslookup`) that the
     current value does not resolve.
  3. Fix `spec.externalName` to point at a real, stable public DNS name
     (`kubernetes.io`) — minimum change necessary, do not change the
     Service's `type`, name, or namespace.
  4. Do not add a `selector` or `ports` — `ExternalName` Services use
     neither; CoreDNS handles this entirely via DNS-level CNAME rewriting,
     with no kube-proxy/Cilium service-proxy involvement at all.

Verification criteria:
  - Service `docs` in `ckne-svc-04` has `spec.type == ExternalName`.
  - `spec.externalName` is a real, resolvable public DNS name.
  - An `nslookup` of `docs.ckne-svc-04.svc.cluster.local` from inside the
    cluster succeeds and the response chain includes the configured
    external name (proving CoreDNS actually performed the CNAME rewrite,
    not a cached/stale answer).
