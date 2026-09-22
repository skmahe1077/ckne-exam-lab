# Concept: NodePort Services

`type: NodePort` builds on top of `ClusterIP` — a NodePort Service still
gets a ClusterIP, but additionally, kube-proxy (or Cilium's eBPF datapath
here) opens the **same port number on every node in the cluster**
(default range 30000-32767) and forwards any traffic that arrives there to
the Service's ClusterIP, which then load-balances across `targetPort` on
the matching Pods — exactly like a ClusterIP Service does internally.

That chain means a NodePort Service can fail for any of the same reasons a
ClusterIP Service can fail (bad selector, wrong `targetPort`), plus one
NodePort-specific failure mode: nothing actually listening/allowed on the
node's external network path to that port. On this cluster, the AWS
security group only opens the NodePort range to traffic **originating
inside the cluster's own security group** — laptops outside the VPC cannot
reach a NodePort directly unless an admin explicitly widens
`ALLOWED_NODEPORT_CIDR`. That's a deliberate security boundary, not a bug:
testing a NodePort Service from an in-cluster Pod against a node's private
IP is the correct way to validate it here, exactly the same way a debug
Pod is used to validate ClusterIP Services.

`targetPort` is independent of all of that: it's the last hop, from the
Service to the container. Even with `type: NodePort` correctly configured
and Endpoints correctly populated, a wrong `targetPort` breaks the final
leg in exactly the way it would for a plain ClusterIP Service.
