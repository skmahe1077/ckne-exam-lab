# Concept: LoadBalancer Services

`type: LoadBalancer` is a strict superset of `type: NodePort`, which is
itself a superset of `type: ClusterIP`. When you create a LoadBalancer
Service, Kubernetes still:

- Allocates a ClusterIP (same as always).
- Allocates a nodePort on every node (same as `type: NodePort`).
- **Additionally**, writes a request for an external load balancer into
  the Service object and waits for a **cloud-controller-manager** (AWS,
  GCP, Azure, etc.) or a bare-metal LB controller (e.g. MetalLB) to notice
  that request and provision an actual external IP, then write it back
  into `status.loadBalancer.ingress`.

That provisioning step is not part of core Kubernetes at all — it's
entirely delegated to whatever controller is watching Services of type
LoadBalancer in your cluster. A bare kubeadm cluster with no cloud
provider integration has **no such controller running**. Nothing is
"broken" in that situation: the Service object is entirely correct, the
API server accepted it, kube-proxy/Cilium programmed the ClusterIP and
nodePort paths exactly like it would for any other Service type — there
is simply no external actor able to complete the last step Kubernetes
itself doesn't implement.

This is why `EXTERNAL-IP` showing `<pending>` forever, on this specific
cluster, is the *correct* signal to recognize and explain — not a defect
to "fix" by, say, editing the Service further. In a real cloud environment
the same manifest would receive a real external IP within seconds/minutes
of the cloud-controller-manager reconciling it. Understanding which layer
(Kubernetes API vs. external controller) is responsible for which part of
a LoadBalancer Service's behaviour is the actual skill being tested here.
