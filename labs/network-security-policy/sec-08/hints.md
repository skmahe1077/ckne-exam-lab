# Hints — SEC-08

## Level 1

Check what's currently (not) protecting `backend`, and confirm the
starting encryption state:

```bash
kubectl -n ckne-sec-08 get ciliumnetworkpolicy
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}'; echo
```

## Level 2

For Part A, test each caller/method/path combination individually before
writing the policy, so you know exactly what "currently open" looks like:

```bash
kubectl -n ckne-sec-08 exec caller   -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-08.svc.cluster.local/admin -X POST
kubectl -n ckne-sec-08 exec outsider -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-08.svc.cluster.local/health
```

For Part B, remember the lock (`cilium-config`) is already acquired by
`setup.sh` — you only need to run the `helm upgrade` yourself.

## Level 3

Part A: write one `CiliumNetworkPolicy` with `endpointSelector: {matchLabels:
{app: backend}}` and a single ingress rule combining `fromEndpoints:
[{matchLabels: {app: caller}}]` with `toPorts` restricted to TCP/80 and an
L7 `rules.http` entry for `method: GET`, `path: /health` — see
`manifests/expected/backend-l7-http.yaml`.

Part B:

```bash
helm upgrade cilium cilium/cilium --reuse-values \
  --set encryption.enabled=true --set encryption.type=wireguard \
  --namespace kube-system --wait --timeout 5m
```

Then confirm with `kubectl -n kube-system get configmap cilium-config -o
jsonpath='{.data.enable-wireguard}'` and `cilium-dbg status --brief` (or
`cilium status --brief`) inside a `cilium` agent Pod.
