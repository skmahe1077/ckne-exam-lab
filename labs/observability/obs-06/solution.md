# CKNE-OBS-06 — Solution

## Root cause

`client-config`'s `CLIENT_TIMEOUT_SECONDS` is `1`, far tighter than `backend`'s real, legitimate processing time (~3s). Every request the client makes aborts before `backend` ever finishes — from the network's point of view this looks exactly like a lost/dropped connection (a TCP RST torn down early), even though nothing was actually dropped.

## Investigation process

A real request with the current 1s timeout fails:

```bash
kubectl -n ckne-obs-06 exec client -c client -- wget -q -T 1 -O- \
  http://backend.ckne-obs-06.svc.cluster.local:8080/process?nonce=diag
# wget: download timed out
```

Check all three independent signals before touching the ConfigMap. Hubble shows the connection to `backend` was actually established (`FORWARDED`) — not a policy drop or an unreachable destination:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace ckne-obs-06 --last 100
```

Prometheus confirms backend's own, independently-measured processing delay is real and non-trivial:

```bash
kubectl -n ckne-obs-06 exec client -c client -- wget -qO- \
  "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs06_backend_delay_seconds"
# {"status":"success","data":{"resultType":"vector","result":[{"metric":{...},"value":[...,"3"]}]}}
```

`backend`'s own logs show it genuinely finishes processing requests it receives — just after the client had already given up:

```bash
kubectl -n ckne-obs-06 logs deployment/backend --tail=50
# PROCESSED request nonce=diag delay=3.0s count=1
```

Together: the connection was established, the server really is that slow (confirmed by its own metric), and it really did finish the work. Nothing was dropped — the client's timeout is simply shorter than backend's genuine response time.

## Corrected configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: client-config
  namespace: ckne-obs-06
data:
  CLIENT_TIMEOUT_SECONDS: "6"
```

Equivalent inline patch:

```bash
kubectl -n ckne-obs-06 patch configmap client-config --type=json \
  -p '[{"op":"replace","path":"/data/CLIENT_TIMEOUT_SECONDS","value":"6"}]'
```

## Verification steps

```bash
kubectl -n ckne-obs-06 exec client -c client -- wget -q -T 6 -O- \
  http://backend.ckne-obs-06.svc.cluster.local:8080/process?nonce=verify
# processed nonce=verify after 3.0s

make validate LAB=OBS-06
```

## Why this works

A request that "just fails" can mean two very different things: genuine packet loss (dropped by policy, a broken route, a crashed process — no amount of waiting would help), or a client giving up too early on a server that would have succeeded. To every layer downstream, both look identical — no response, connection torn down abruptly. Telling them apart requires correlating three independent signals, since none alone is conclusive: Hubble confirms the connection was actually established on the wire (ruling out "nothing could reach the destination"), Prometheus's `obs06_backend_delay_seconds` gives the server's own independently-measured processing time, and backend's application log proves it genuinely processed the specific request, just later than the client waited. With all three agreeing the backend is slow-but-healthy, raising `CLIENT_TIMEOUT_SECONDS` to a value with reasonable margin above the real ~3s delay is what actually fixes the symptom — nothing about Cilium, Hubble, Prometheus, or the network itself was ever broken.

## Faster exam-oriented method

One real request with a short timeout reproduces the failure immediately; a single Prometheus query for `obs06_backend_delay_seconds` gives the real number to size the fix against. Patch `CLIENT_TIMEOUT_SECONDS` to roughly 2x the observed delay (comfortable margin, still tight enough to catch a real regression) and re-test once.

## Common mistakes

- Modifying the `backend` Deployment or its `DELAY_SECONDS` env var to "speed it up" — explicitly out of scope; the backend's ~3s processing time is legitimate and fixed, not a bug to fix.
- Treating the failure as a dropped-connection/network problem and investigating NetworkPolicies, Cilium, or routing — Hubble already shows the flow was `FORWARDED`, ruling this out; the fault is entirely in the client's timeout configuration.
- Setting `CLIENT_TIMEOUT_SECONDS` to an extremely large value (e.g. 60+) "to be safe" — works but would mask a real future regression in backend's latency instead of catching it, and the task specifically calls for a value with sane margin (4–15s), not an unreasonably large one.
- Relying on only one of the three signals (e.g. just re-running the request with a longer timeout) instead of correlating Hubble, Prometheus, and logs together — the task specifically exercises using multiple independent signals to distinguish "client gave up early" from genuine packet loss, not guessing from a single retry.

## Relevant documentation

- Cilium Hubble — https://docs.cilium.io/en/stable/observability/hubble/
- Prometheus HTTP API — https://prometheus.io/docs/prometheus/latest/querying/api/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Logging architecture — https://kubernetes.io/docs/concepts/cluster-administration/logging/
