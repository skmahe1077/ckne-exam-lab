Task ID: OBS-01
Domain: Observability
Difficulty: beginner
Estimated time: 15 minutes
Cluster: ckne-hands-on (kubeadm, 1 control-plane + 2 workers, Cilium CNI)
Host: control plane (kubectl runs against the cluster; no SSH required)
Context: default (uses your current kubeconfig context)
Namespace: ckne-obs-01

Scenario:
  A `backend` Deployment + Service and a `netprobe` Deployment (2 replicas)
  were deployed into the `ckne-obs-01` namespace. `netprobe` is supposed to
  continuously reach `backend` over the network, but its Pods are stuck
  restarting and never become Ready.

Objective:
  Use Kubernetes Events and the netprobe container's own application logs —
  not guesswork — to find the real cause of the network failure, then fix it
  so `netprobe` reaches `backend` successfully and stays Ready.

Requirements:
  1. List the Events for the `ckne-obs-01` namespace and identify what
     Kubernetes itself is reporting about the `netprobe` Pods
     (`kubectl -n ckne-obs-01 get events --sort-by=.lastTimestamp`).
  2. Read the netprobe container's own application logs
     (`kubectl -n ckne-obs-01 logs <pod>`) to see the specific error message
     it logs immediately before exiting.
  3. Determine the root cause: is this a broken backend, a broken Service,
     or a misconfiguration inside netprobe itself? Confirm your hypothesis
     before changing anything.
  4. Fix the actual root cause with the minimum change necessary. Do not
     change the `backend` Deployment or Service — they are already correct.
  5. `netprobe` must reach `2/2` Ready and stop restarting, with its logs
     showing successful reaches of `backend`, not just an absence of errors.

Verification criteria:
  - `backend` Deployment in `ckne-obs-01` remains `1/1` Ready (unchanged
    precondition).
  - Deployment `netprobe` in `ckne-obs-01` has `status.readyReplicas == 2`.
  - No `netprobe` Pod is in `CrashLoopBackOff`.
  - At least one `netprobe` Pod's logs contain a line beginning `OK: reached`
    within its most recent output — proof of an actual successful network
    request, not just a Running Pod status.
