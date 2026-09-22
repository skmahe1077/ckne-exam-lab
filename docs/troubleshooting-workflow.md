# General Troubleshooting Workflow

The order that pays off across almost every lab in this repository (and the
real exam):

1. **Is the shared infrastructure healthy?** Before assuming a lab-specific
   bug, rule out the cluster-wide pieces every lab depends on:
   ```bash
   kubectl get nodes
   kubectl -n kube-system get daemonset cilium
   kubectl -n kube-system rollout status deployment/coredns
   ```
   `make cluster-verify` runs this class of check for you.

2. **Is the object even scheduled?** `kubectl get pod -o wide` — look at
   `NODE` and `STATUS`. `Pending` means the scheduler never placed it
   (check `nodeSelector`/affinity/taints/resources); the CNI/network layer
   was never even invoked yet, so don't debug networking for a `Pending` Pod.

3. **What do the Events say?** `kubectl describe pod|svc|... -n <ns>` and
   `kubectl get events -n <ns> --sort-by=.lastTimestamp`. Kubernetes usually
   tells you exactly what's wrong — read it before guessing.

4. **Does the object's config actually match intent?** Compare selectors,
   labels, ports (`port` vs `targetPort` vs `containerPort`), and namespaces
   side by side. Most Service/NetworkPolicy/HTTPRoute bugs in this
   repository are a mismatch here, not a deeper platform issue.

5. **Prove runtime behavior, don't infer it.** `kubectl exec` into a
   debug pod (`nicolaka/netshoot` or `busybox`) and actually make the
   request: `curl`, `nc -zv`, `nslookup`/`dig`, `ss`, `tcpdump`. An object
   looking correct is not the same as traffic actually flowing — this
   repository's own `validate.sh` scripts follow the same principle and
   never pass on object-existence alone.

6. **For anything involving Cilium/Istio specifically**, check their own
   status surfaces before assuming a plain Kubernetes explanation:
   `cilium status`, `hubble observe`, `istioctl`-equivalent
   (`kubectl get peerauthentication,authorizationpolicy`), and the sidecar's
   own logs (`kubectl logs <pod> -c istio-proxy`).

7. **If a lab touches a shared/cluster-scoped resource** (CoreDNS, the
   Cilium Helm release, a mesh-wide Istio setting), check
   `make active-labs` first — a failure might be someone else's
   (or your own stale) lock, not your task.
