# Concept: Default-Deny Egress and the DNS Trap

Just like ingress, the moment ANY NetworkPolicy with `policyTypes: [Egress]`
selects a Pod, that Pod's outbound traffic flips from "allow everything" to
"deny everything except what an Egress rule explicitly allows." The most
common mistake when writing a default-deny-egress policy is forgetting that
this also blocks **DNS** — a Pod's own lookup of a Service's ClusterIP goes
out over UDP/TCP port 53 to CoreDNS, which is itself traffic subject to the
same policy. Without an explicit allow rule for DNS, a Pod under
default-deny-egress cannot resolve ANY name — not even ones inside its own
namespace — so even an otherwise-correct "allow egress to allowed-svc" rule
appears to fail, because the Pod can't look up `allowed-svc`'s IP in the
first place.

The fix is always two parts:
1. An egress rule allowing UDP+TCP/53 to CoreDNS — selected via
   `namespaceSelector` matching `kube-system` and `podSelector` matching
   CoreDNS's Pod label (`k8s-app: kube-dns` on a standard kubeadm cluster).
2. An egress rule allowing the specific application traffic you actually
   need (here, TCP/80 to Pods labeled `app: allowed-target`).

As with ingress, egress rules from separate NetworkPolicies selecting the
same Pod are additive — you extend `default-deny-egress`'s effect with a new
policy rather than editing it, keeping the deny-by-default posture intact
everywhere except the two paths you explicitly opened.
