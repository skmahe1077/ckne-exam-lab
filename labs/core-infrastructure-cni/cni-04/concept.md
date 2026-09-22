# Concept: Diagnosing Pod-to-Pod Connectivity

`kubectl get pods` and `kubectl get svc` only tell you what Kubernetes
*intends* — a Pod being Ready only means its containers started and passed
whatever probes (if any) were defined; a Service existing only means the
object was accepted by the API server. Neither one tells you whether
traffic is actually flowing end-to-end. Between "the objects look correct"
and "the traffic works" sits the real network path: kube-proxy or Cilium's
datapath forwards a Service connection to one of its endpoint Pod IPs, and
that Pod's own kernel decides what to do with the packet once it arrives.

Two tools close that gap by showing you what's *actually happening*, not
what's *configured*:

- **`ss`** (socket statistics) lists the sockets a process has open right
  now — in particular, `ss -tlnp` shows exactly which ports are actually
  being listened on inside a given network namespace. This directly
  answers "is anything even listening on the port traffic is being sent
  to?" — a question `kubectl describe` cannot answer, because Kubernetes
  doesn't introspect the application's actual socket state.
- **`tcpdump`** captures packets on an interface as they arrive or leave.
  Run against a Pod's `eth0` while a connection attempt is in flight, it
  shows you whether a `SYN` ever arrived, whether it got a `SYN-ACK` back,
  or whether the kernel immediately answered with a `RST` (a strong signal
  that something reached the right IP but the wrong, or no, listening
  port).

A very common real-world bug this combination catches: a Service's
`targetPort` doesn't match the port the container process actually binds
to. The Service and Endpoints objects look completely correct — the
mismatch only exists between the YAML and the running process, and only
`ss`/`tcpdump` (or an actual connection attempt) reveal it. Because
containers in the same Pod share one network namespace, a small debug
sidecar with these tools installed can inspect a workload container's real
socket and packet state without needing to install anything inside the
workload's own (often minimal) image.
