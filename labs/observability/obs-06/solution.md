# Solution — OBS-06

## Diagnosis

1. A real request with the current 1s timeout fails:

   ```bash
   kubectl -n ckne-obs-06 exec client -c client -- wget -q -T 1 -O- \
     http://backend.ckne-obs-06.svc.cluster.local:8080/process?nonce=diag
   # wget: download timed out
   ```

2. Hubble shows the connection to backend was actually established
   (`FORWARDED`) — it's not a policy drop or an unreachable destination:

   ```bash
   kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace ckne-obs-06 --last 100
   ```

3. Prometheus confirms backend's own, independently-measured processing
   delay is real and non-trivial:

   ```bash
   kubectl -n ckne-obs-06 exec client -c client -- wget -qO- \
     "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs06_backend_delay_seconds"
   # {"status":"success","data":{"resultType":"vector","result":[{"metric":{...},"value":[...,"3"]}]}}
   ```

4. `backend`'s own logs show it genuinely finishes processing requests it
   receives — just after the client had already given up:

   ```bash
   kubectl -n ckne-obs-06 logs deployment/backend --tail=50
   # PROCESSED request nonce=diag delay=3.0s count=1
   ```

   Together: the connection was established, the server really is that
   slow (confirmed by its own metric), and it really did finish the work.
   Nothing was dropped — the client's timeout is simply shorter than
   backend's genuine response time.

## Fix

Raise `CLIENT_TIMEOUT_SECONDS` in `client-config` to a value with a
reasonable margin above backend's real ~3s delay (see
`manifests/expected/client-config.yaml`):

```bash
kubectl -n ckne-obs-06 patch configmap client-config --type=json \
  -p '[{"op":"replace","path":"/data/CLIENT_TIMEOUT_SECONDS","value":"6"}]'
```

## Verify

```bash
kubectl -n ckne-obs-06 exec client -c client -- wget -q -T 6 -O- \
  http://backend.ckne-obs-06.svc.cluster.local:8080/process?nonce=verify
# processed nonce=verify after 3.0s

make validate LAB=OBS-06
```

Neither Cilium, Hubble, Prometheus, nor the network itself were ever
broken — the exercise is precisely that "the request never came back" can
have a client-side cause with zero relationship to actual packet loss, and
the only way to be sure is to correlate what the network actually did
(Hubble), what the server actually measured (Prometheus), and what the
server actually logged — not to assume the first plausible network-looking
explanation.
