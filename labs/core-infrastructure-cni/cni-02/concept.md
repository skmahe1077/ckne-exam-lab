# Concept: Pod CIDR and IPAM Allocation

Every Kubernetes cluster reserves a range of IP addresses — the **cluster
Pod CIDR** — that no individual node owns outright. At cluster bootstrap
that range is declared once (`podSubnet` in this cluster's `kubeadm.config`,
set to `10.244.0.0/16`) and then subdivided: each node is handed a smaller
slice of it (commonly a /24, controlled by `node-cidr-mask-size`), and the
CNI plugin's **IPAM (IP Address Management)** component allocates individual
Pod IPs to that node out of its slice as Pods are scheduled there.

With Cilium, IPAM runs per-node: each `cilium` Pod on a node claims a block
from the cluster's Pod CIDR and hands out addresses from it as the kubelet
asks Cilium to network new Pods. This is why every Pod IP you see with
`kubectl get pods -o wide` — regardless of which node it landed on — falls
inside `10.244.0.0/16`: that invariant is enforced structurally, not by
convention.

This matters operationally any time you write something that has to *know*
what a Pod IP can look like — most commonly a `NetworkPolicy` `ipBlock`
rule, or an external firewall/route table entry. If that CIDR is wrong —
too narrow, shifted, or simply a typo — the rule silently matches nothing,
because no Pod will ever actually get an IP in the wrong range. There is no
error; the objects apply cleanly and look correct at a glance. The only way
to catch it is to check what IPs Pods are *actually* being assigned and
compare that against what the rule claims to allow.

Don't guess the Pod CIDR from memory or documentation — always confirm it
against real, running Pods (`kubectl get pods -A -o wide`), since it is a
per-cluster/per-installation value that any lab or production environment
could set differently.
