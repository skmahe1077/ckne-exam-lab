# Solution — OBS-01

## Diagnosis

1. Events show the netprobe Pods repeatedly restarting:

   ```bash
   kubectl -n ckne-obs-01 get events --sort-by=.lastTimestamp
   # Warning  BackOff  ...  Back-off restarting failed container
   ```

2. The container's own logs name the exact problem:

   ```bash
   kubectl -n ckne-obs-01 logs -l app=netprobe --tail=20
   # netprobe starting, TARGET_URL=http://backend-svc.ckne-obs-01.svc.cluster.local
   # ERROR: failed to reach http://backend-svc.ckne-obs-01.svc.cluster.local (DNS/connection failure)
   ```

3. `kubectl -n ckne-obs-01 get svc` shows the real Service is named
   `backend`, not `backend-svc` — the netprobe Deployment's `TARGET_URL` env
   var has a typo'd hostname that never resolves.

## Fix

Correct the `TARGET_URL` env var (see `manifests/expected/netprobe.yaml`
for the full corrected object):

```bash
kubectl -n ckne-obs-01 set env deployment/netprobe \
  TARGET_URL="http://backend.ckne-obs-01.svc.cluster.local"
```

## Verify

```bash
kubectl -n ckne-obs-01 rollout status deployment/netprobe
kubectl -n ckne-obs-01 logs -l app=netprobe --tail=5
# OK: reached http://backend.ckne-obs-01.svc.cluster.local
make validate LAB=OBS-01
```

The backend and its Service were never broken — the exercise is precisely
that Events tell you *something* is wrong, but only the application's own
logs tell you *what*.
