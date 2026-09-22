# Concept: Multi-Interface Pods

## What a real multi-interface Pod is

By default, a Pod gets exactly **one** network interface (`eth0`), owned and
programmed entirely by the primary CNI plugin — Cilium in this cluster. A
"multi-interface Pod" attaches one or more *additional* NICs to the Pod's
network namespace, each potentially on a completely different network, with
its own IP, its own routes, and sometimes its own separate security
boundary. This is used for things like: a dedicated high-throughput data
plane NIC (e.g. SR-IOV or macvlan straight onto a physical network) alongside
the normal cluster-overlay `eth0` used for control traffic, or attaching a
Pod directly onto a telco/NFV network that must stay isolated from the
regular Pod network.

The standard mechanism for this is **Multus CNI** — a "meta-plugin" that
sits in front of the primary CNI and, driven by `NetworkAttachmentDefinition`
CRDs and a `k8s.v1.cni.cncf.io/networks` Pod annotation, invokes one or more
*additional* CNI plugins (macvlan, ipvlan, host-device, another instance of
a bridge plugin, etc.) to add extra interfaces into the Pod's netns on top
of whatever the primary CNI (Cilium) already provisioned.

## What is and is not simulated in this lab — read this carefully

**Multus is NOT installed in this cluster and this lab does not install
it.** That means:

- This lab's Pod has exactly **one** real network interface and **one**
  `podIP`, exactly like every other Pod in this cluster. You will verify
  this directly (`status.podIPs` has a single entry).
- No `NetworkAttachmentDefinition` CRD, no `k8s.v1.cni.cncf.io/networks`
  annotation, and no secondary CNI plugin (macvlan/ipvlan/SR-IOV) appears
  anywhere in this lab. None of that is real here.

What **is** demonstrated, faithfully, is the *reason* multi-interface Pods
exist: giving different traffic planes inside the same Pod independent
reachability rules. This lab approximates that with tools that are actually
available:

- A single Pod runs **two containers**, each binding a distinct port:
  `data-plane` (port 8080) and `mgmt-plane` (port 9090) — standing in for
  what, with Multus, would instead be two separate NICs/IPs.
- Two Services (`data-svc`, `mgmt-svc`) each front one of those ports —
  standing in for two separately-routable network attachments.
- A single `NetworkPolicy` enforces **different ingress rules per port**,
  the same way a real multi-interface deployment would enforce different
  security policy per NIC: the data plane is reachable from any Pod in the
  namespace, while the management plane is reachable only from Pods labeled
  `role: admin`.

This is a legitimate way to reason about "does this traffic belong on the
privileged/management plane or the general data plane?" even without a
second real NIC — but do not walk away thinking a `NetworkPolicy` per-port
rule is a substitute for genuine network-layer isolation (a compromised
container in the same Pod's network namespace can still see the raw
interface `mgmt-plane` binds to; a second real NIC on an isolated physical/
overlay network is a stronger boundary than a second port on the same
`eth0`). Real Multus usage is out of scope for this lab entirely.

## Why this still belongs in "Core Infrastructure and CNI"

Understanding when a workload *needs* a genuine secondary interface (versus
when a NetworkPolicy per Service/port is sufficient) is itself an exam-level
judgment call — recognizing "this cluster has no Multus, so what's the
next-best mechanism to express the same security intent with the primitives
that do exist" is exactly the kind of diagnostic reasoning the CKNE tests.
