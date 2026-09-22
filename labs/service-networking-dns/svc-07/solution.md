# Solution — SVC-07

## Diagnosis

1. kube-proxy is running in `iptables` mode cluster-wide:

   ```bash
   kubectl -n kube-system get daemonset kube-proxy
   kubectl -n kube-system get configmap kube-proxy -o yaml | grep -A2 "mode:"
   # mode: "iptables"  (or blank, which also means iptables — it's the default)
   ```

2. `ckne-svc-07` already has a healthy `web` Deployment (2/2 Ready) but no
   Service — `kubectl -n ckne-svc-07 get service` returns nothing.

## Fix

Create the Service (see `manifests/expected/service.yaml`):

```bash
kubectl -n ckne-svc-07 apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ckne-svc-07
  labels:
    app: web
    app.kubernetes.io/part-of: ckne-hands-on
    ckne.openai.com/lab-id: "SVC-07"
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF
```

## Inspect kube-proxy's iptables rules

Get the ClusterIP, then run a `hostNetwork` debug Pod with `NET_ADMIN`/
`NET_RAW` to read the node's actual netfilter rules:

```bash
CLUSTER_IP=$(kubectl -n ckne-svc-07 get service web -o jsonpath='{.spec.clusterIP}')

kubectl -n ckne-svc-07 run iptables-check --image=nicolaka/netshoot:latest \
  --restart=Never --rm -i \
  --overrides="{\"spec\":{\"hostNetwork\":true,\"containers\":[{\"name\":\"iptables-check\",\"image\":\"nicolaka/netshoot:latest\",\"command\":[\"sh\",\"-c\",\"iptables-save | grep $CLUSTER_IP\"],\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\",\"NET_RAW\"]}}}]}}"
```

You should see output like:

```
-A KUBE-SERVICES -d 10.96.x.x/32 -p tcp -m comment --comment "ckne-svc-07/web:http cluster IP" -m tcp --dport 80 -j KUBE-SVC-XXXXXXXXXXXXXXXX
-A KUBE-SVC-XXXXXXXXXXXXXXXX ! -s 10.244.0.0/16 -d 10.96.x.x/32 ... -j KUBE-MARK-MASQ
-A KUBE-SVC-XXXXXXXXXXXXXXXX -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-AAAAAAAAAAAAAAAA
-A KUBE-SVC-XXXXXXXXXXXXXXXX -j KUBE-SEP-BBBBBBBBBBBBBBBB
```

`KUBE-SERVICES` matches the ClusterIP and jumps into a per-Service
`KUBE-SVC-*` chain, which uses `--probability` to randomly split traffic
across one `KUBE-SEP-*` (Service EndPoint) chain per ready Pod — each of
which DNATs to that Pod's actual IP. This is the whole mechanism: a
regular Pod's own `iptables-save` would show none of this, because these
rules live in the node's root network namespace, only visible from a
Pod that explicitly shares it via `hostNetwork: true`.

## Verify

```bash
kubectl -n ckne-svc-07 get endpoints web
make validate LAB=SVC-07
```

Nothing about kube-proxy or the shared cluster configuration was changed —
this lab is purely observational once the Service exists.
