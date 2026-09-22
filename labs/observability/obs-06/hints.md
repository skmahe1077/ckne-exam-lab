# Hints — OBS-06

## Level 1

Try a real request yourself and see what happens:

```bash
kubectl -n ckne-obs-06 get configmap client-config -o yaml
kubectl -n ckne-obs-06 exec client -c client -- wget -q -T 1 -O- http://backend.ckne-obs-06.svc.cluster.local:8080/process?nonce=test
echo "exit code: $?"
```

Does it succeed or time out? How long did it actually take before giving
up?

## Level 2

Check all three signals independently before touching the ConfigMap:

```bash
# Hubble: what does the flow actually look like at the network layer?
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -- hubble observe --namespace ckne-obs-06 --last 100

# Prometheus: what does backend itself report as its real processing delay?
kubectl -n ckne-obs-06 exec client -c client -- wget -qO- \
  "http://prometheus-server.monitoring.svc.cluster.local/api/v1/query?query=obs06_backend_delay_seconds"

# Logs: did backend actually process the request?
kubectl -n ckne-obs-06 logs deployment/backend --tail=50
```

Do these three signals point at a dropped/lost connection, or at something
else entirely?

## Level 3

```bash
kubectl -n ckne-obs-06 get configmap client-config -o jsonpath='{.data.CLIENT_TIMEOUT_SECONDS}'
```

Compare that number against the real delay Prometheus just reported. Patch
`CLIENT_TIMEOUT_SECONDS` to a value with a sane margin above it — not so
tight it keeps failing, not so large it would hide a real future
regression — then re-run your test request.
