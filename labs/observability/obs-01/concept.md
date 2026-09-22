# Concept: Kubernetes Events and Application Logs for Network Issues

When a Pod cannot reach another Pod or Service, there are two independent,
free sources of diagnostic signal available before you touch `tcpdump`,
Hubble, or any other network-layer tool:

**Kubernetes Events** (`kubectl get events`, or the `Events:` section at the
bottom of `kubectl describe pod`) are emitted by the kubelet, the scheduler,
and controllers whenever something observable happens to an object — a Pod
failing its restart backoff (`Warning BackOff Back-off restarting failed
container`), a container repeatedly exiting non-zero, a failed liveness
probe, and so on. Events tell you *what Kubernetes observed happening to the
object*, but not *why* the application itself failed — for that, you need
the second source.

**Application logs** (`kubectl logs <pod>`, and `kubectl logs <pod>
--previous` for a container that already restarted) are whatever the
process inside the container wrote to stdout/stderr. A well-behaved
application logs the specific error it hit — a DNS resolution failure, a
connection refused, a timeout — right before it exits. This is almost
always faster than reasoning from Events alone, because the application
usually already did the diagnosis for you in its error message.

The discipline this lab exercises: **read both before touching anything.**
A crash-looping Pod's Events will tell you Kubernetes keeps restarting it;
only the logs tell you the network target was wrong. Guessing at fixes
without reading either wastes time and risks masking the real problem
(e.g., raising `initialDelaySeconds` or resources instead of fixing the
actual misconfigured target).
