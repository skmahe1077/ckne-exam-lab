# CKNE-SVC-07 — Solution

## Root cause

No bug to find — `ckne-svc-07` already has a healthy `web` Deployment (2/2 Ready) but no Service at all. The exercise is to create the Service and then prove, by directly reading the node's iptables rules, that kube-proxy actually programmed a path from the ClusterIP to the Pods.

## Investigation process

Confirm kube-proxy's mode and health first:

```bash
kubectl -n kube-system get daemonset kube-proxy
kubectl -n kube-system get configmap kube-proxy -o yaml | grep -A2 "mode:"
# mode: "iptables"  (or blank, which also means iptables — it's the default)
```

Then look at what already exists in the namespace:

```bash
kubectl -n ckne-svc-07 get deployment,pods -o wide
kubectl -n ckne-svc-07 get service
```

A Deployment exists but no Service — that's the first thing to create.

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ckne-svc-07
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
```

```bash
kubectl -n ckne-svc-07 apply -f labs/service-networking-dns/svc-07/manifests/expected/service.yaml
```

Then inspect kube-proxy's iptables rules. A normal Pod's own `iptables-save` shows nothing about Services — kube-proxy's rules live in the node's root network namespace, so a debug Pod must join it via `hostNetwork: true` plus `NET_ADMIN`/`NET_RAW`:

```bash
CLUSTER_IP=$(kubectl -n ckne-svc-07 get service web -o jsonpath='{.spec.clusterIP}')

kubectl -n ckne-svc-07 run iptables-check --image=nicolaka/netshoot:latest \
  --restart=Never --rm -i \
  --overrides="{\"spec\":{\"hostNetwork\":true,\"containers\":[{\"name\":\"iptables-check\",\"image\":\"nicolaka/netshoot:latest\",\"command\":[\"sh\",\"-c\",\"iptables-save | grep $CLUSTER_IP\"],\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\",\"NET_RAW\"]}}}]}}"
```

Expected output:

```
-A KUBE-SERVICES -d 10.96.x.x/32 -p tcp -m comment --comment "ckne-svc-07/web:http cluster IP" -m tcp --dport 80 -j KUBE-SVC-XXXXXXXXXXXXXXXX
-A KUBE-SVC-XXXXXXXXXXXXXXXX ! -s 10.244.0.0/16 -d 10.96.x.x/32 ... -j KUBE-MARK-MASQ
-A KUBE-SVC-XXXXXXXXXXXXXXXX -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-AAAAAAAAAAAAAAAA
-A KUBE-SVC-XXXXXXXXXXXXXXXX -j KUBE-SEP-BBBBBBBBBBBBBBBB
```

## Verification steps

```bash
kubectl -n ckne-svc-07 get endpoints web
make validate LAB=SVC-07
```

Nothing about kube-proxy or shared cluster configuration was changed — this lab is purely observational once the Service exists.

## Why this works

kube-proxy watches Services and EndpointSlices through the API server and reprograms the node's iptables rules whenever they change. In `iptables` mode, `KUBE-SERVICES` matches a packet's destination against every known ClusterIP and jumps into a per-Service `KUBE-SVC-*` chain, which uses `--probability` to randomly split traffic across one `KUBE-SEP-*` (Service EndPoint) chain per ready Pod, each of which DNATs to that specific Pod's real IP. This mechanism is entirely invisible from inside an ordinary Pod, because every Pod gets its own network namespace separate from the node's — kube-proxy writes into the node's root namespace, which a sandboxed Pod has no visibility into regardless of capabilities. The only way to see it is to make a debug Pod share the node's namespace directly (`hostNetwork: true`) and hold `NET_ADMIN` (conventionally `NET_RAW` too) to actually query netfilter state. Creating the Service is what causes kube-proxy to generate these rules in the first place; reading them back is proof the mechanism worked, not just that the API object exists.

## Faster exam-oriented method

Create the Service with a plain manifest, grab the ClusterIP, and run one `hostNetwork` debug Pod with an inline `iptables-save | grep $CLUSTER_IP` command — no need to explore the ruleset manually beyond that one grep.

## Common mistakes

- Running `iptables-save` inside a normal (non-`hostNetwork`) Pod and concluding kube-proxy isn't working because nothing shows up — an ordinary Pod's own network namespace has zero visibility into the node's iptables rules regardless of what's actually programmed.
- Forgetting `NET_ADMIN`/`NET_RAW` capabilities on the debug Pod — without them, `iptables-save` fails or returns incomplete data even with `hostNetwork: true`.
- Assuming Service creation alone is sufficient proof of working routing without confirming both the EndpointSlice populated and a real request actually succeeds — a Service can exist with a selector/port mismatch that produces no working iptables path even though the object itself looks fine.
- Modifying kube-proxy's ConfigMap or ds while investigating — this lab is purely observational; nothing about kube-proxy's shared, cluster-wide configuration should change.

## Relevant documentation

- kube-proxy iptables mode — https://kubernetes.io/docs/reference/networking/virtual-ips/#proxy-mode-iptables
- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Pod security context — https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
