# CKNE-OBS-01 — Solution

## Root cause

The `netprobe` Deployment's `TARGET_URL` env var points at `http://backend-svc.ckne-obs-01.svc.cluster.local` — a typo'd hostname. The real Service is named `backend`, not `backend-svc`, so every probe loop iteration fails DNS resolution immediately, the container logs an error, and exits non-zero, causing the restart loop.

## Investigation process

Events show the netprobe Pods repeatedly restarting:

```bash
kubectl -n ckne-obs-01 get events --sort-by=.lastTimestamp
# Warning  BackOff  ...  Back-off restarting failed container
```

Events tell you Kubernetes observed a restart loop, but not why. Read the container's own logs for that:

```bash
kubectl -n ckne-obs-01 logs -l app=netprobe --tail=20
# netprobe starting, TARGET_URL=http://backend-svc.ckne-obs-01.svc.cluster.local
# ERROR: failed to reach http://backend-svc.ckne-obs-01.svc.cluster.local (DNS/connection failure)
```

Compare that hostname against the real Service:

```bash
kubectl -n ckne-obs-01 get svc
```

The real Service is `backend`, not `backend-svc`.

## Corrected configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netprobe
  namespace: ckne-obs-01
spec:
  replicas: 2
  selector:
    matchLabels:
      app: netprobe
  template:
    metadata:
      labels:
        app: netprobe
    spec:
      containers:
        - name: netprobe
          image: busybox:1.36
          env:
            - name: TARGET_URL
              value: "http://backend.ckne-obs-01.svc.cluster.local"
          # probe loop unchanged
```

Equivalent inline command:

```bash
kubectl -n ckne-obs-01 set env deployment/netprobe \
  TARGET_URL="http://backend.ckne-obs-01.svc.cluster.local"
```

## Verification steps

```bash
kubectl -n ckne-obs-01 rollout status deployment/netprobe
kubectl -n ckne-obs-01 logs -l app=netprobe --tail=5
# OK: reached http://backend.ckne-obs-01.svc.cluster.local
make validate LAB=OBS-01
```

## Why this works

Kubernetes Events tell you *what Kubernetes observed happening to the object* — a Pod failing its restart backoff, a container repeatedly exiting non-zero — but not *why* the application itself failed. Application logs are whatever the process actually wrote before exiting, and a well-behaved application (like this lab's `netprobe` script) logs the specific error it hit right before dying. Reading both in sequence — Events to confirm something is wrong and how often, logs to see exactly what URL the container tried and failed to reach — points directly at the typo'd hostname without needing to touch `backend` or its Service at all, since neither was ever broken. Correcting `TARGET_URL` to the real Service name is the entire fix; the probe loop logic itself was already correct.

## Faster exam-oriented method

Skip straight to `kubectl logs -l app=netprobe --tail=20` — a crash-looping Pod that logs its own error message almost always tells you the fix directly, faster than reasoning from Events alone. `kubectl set env deployment/netprobe TARGET_URL=...` applies the one-line fix immediately.

## Common mistakes

- Modifying `backend`'s Deployment or Service while hunting for the bug — both are explicitly correct preconditions; the entire fault is in `netprobe`'s own environment variable.
- Reading only Events (which just say "Back-off restarting failed container") and guessing at causes like resource limits or probe timing, instead of reading the container's own logs, which name the exact broken URL.
- Increasing `initialDelaySeconds`, resource limits, or restart tolerance to "fix" the crash loop — masks the symptom without addressing the actual misconfigured target, and the Pod would keep failing indefinitely against the wrong hostname.
- Checking only that the Pod reaches `Running`/`Ready` without confirming the logs show `OK: reached` — the task specifically requires proof of a successful network request, not just an absence of visible errors at a glance.

## Relevant documentation

- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Determine the reason for Pod failure — https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/
- Logging architecture — https://kubernetes.io/docs/concepts/cluster-administration/logging/
- kubectl logs reference — https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
