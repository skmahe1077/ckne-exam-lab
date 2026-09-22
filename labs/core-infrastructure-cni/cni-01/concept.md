# Concept: CNI Installation and Configuration

Kubernetes does not implement Pod networking itself — the kubelet calls out
to a **Container Network Interface (CNI)** plugin every time a Pod's network
namespace needs to be set up or torn down. That plugin is responsible for:

- Assigning the Pod an IP address (IPAM).
- Wiring the Pod's network namespace into the node's network (usually via a
  veth pair + a bridge or an overlay).
- Programming routing/NAT rules so Pods can reach other Pods, Services, and
  (if allowed) the internet.

This cluster uses **Cilium** as its CNI. Cilium runs as a DaemonSet
(`cilium`, in `kube-system`) — one Pod per node — plus an operator
Deployment. Each `cilium` Pod:

- Writes the CNI configuration file nodes read from (`/etc/cni/net.d/`) so
  the kubelet knows to hand Pod networking off to Cilium.
- Manages IP allocation for that node out of the cluster's Pod CIDR
  (`10.244.0.0/16` in this environment — see CNI-02 for IPAM specifics).
- Programs eBPF datapath rules (instead of traditional iptables-heavy
  approaches) to route and secure Pod traffic.

**A Pod that never becomes Ready is not automatically a CNI problem.** The
kubelet only asks the CNI plugin to network a Pod once the scheduler has
already placed it on a node. If the scheduler can't place the Pod at all —
because of `nodeSelector`/`affinity`/`taint` mismatches, insufficient
resources, or similar — the Pod stays `Pending` and CNI is never even
invoked. Jumping straight to "reinstall the CNI" without first checking
`kubectl describe pod` / `kubectl get events` wastes time and risks breaking
a shared, cluster-wide component that every other lab also depends on.

The diagnostic order that matters here:

1. Is the CNI itself healthy cluster-wide? (`kubectl -n kube-system get
   daemonset cilium`, `kubectl -n kube-system get pods -l k8s-app=cilium`)
2. Is the Pod even scheduled? (`kubectl get pod -o wide`, look at `NODE` and
   `STATUS`)
3. If `Pending`: read the Events — the scheduler explains exactly why it
   couldn't place the Pod.
4. Only if the Pod IS scheduled but stuck in `ContainerCreating`/`CrashLoop`
   with CNI-related errors in its Events does the investigation actually
   point back at the CNI layer.
