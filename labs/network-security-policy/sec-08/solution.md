# CKNE-SEC-08 — Solution

## Root cause

**Part A:** `backend` has no `CiliumNetworkPolicy` at all — its nginx config returns HTTP 200 for any path/method from any Pod, including `outsider` and `caller`'s `POST /admin`. **Part B:** Cilium's WireGuard transparent encryption is not yet enabled cluster-wide (`enable-wireguard` is unset/false in `cilium-config`).

## Investigation process

Check what's currently (not) protecting `backend`, and confirm the starting encryption state:

```bash
kubectl -n ckne-sec-08 get ciliumnetworkpolicy
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}'; echo
```

**Part A:** test each caller/method/path combination individually before writing the policy, so you know exactly what "currently open" looks like:

```bash
kubectl -n ckne-sec-08 exec caller   -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-08.svc.cluster.local/admin -X POST
kubectl -n ckne-sec-08 exec outsider -- curl -s -o /dev/null -w '%{http_code}\n' http://backend.ckne-sec-08.svc.cluster.local/health
```

Both currently succeed (200) — no access control exists yet.

**Part B:** the `cilium-config` lock is already acquired by `setup.sh` — only the `helm upgrade` itself needs to be run.

## Corrected configuration

**Part A — L7 CiliumNetworkPolicy (namespace-scoped, no lock):**

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-l7-http
  namespace: ckne-sec-08
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: caller
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/health"
```

```bash
kubectl apply -f labs/network-security-policy/sec-08/manifests/expected/backend-l7-http.yaml
```

**Part B — Transparent Encryption (cluster-wide, lock required):**

```bash
helm upgrade cilium cilium/cilium --reuse-values \
  --set encryption.enabled=true --set encryption.type=wireguard \
  --namespace kube-system --wait --timeout 5m
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

## Verification steps

**Part A:**

```bash
kubectl -n ckne-sec-08 exec caller   -- curl -s -o /dev/null -w '%{http_code}\n' -X GET  http://backend.ckne-sec-08.svc.cluster.local/health   # 200
kubectl -n ckne-sec-08 exec caller   -- curl -s -o /dev/null -w '%{http_code}\n' -X POST http://backend.ckne-sec-08.svc.cluster.local/admin    # 403 (or timeout)
kubectl -n ckne-sec-08 exec outsider -- curl -s -o /dev/null -w '%{http_code}\n' -X GET  http://backend.ckne-sec-08.svc.cluster.local/health   # timeout
```

**Part B:**

```bash
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}'; echo   # true
CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium-dbg status --brief | grep -i wireguard
make validate LAB=SEC-08
```

`cleanup.sh` reverts `encryption.enabled=false` via the same `--reuse-values` pattern and then releases the `cilium-config` lock, so the next lab (or ATM-05, which shares this same lock name by design since both labs touch Cilium's Helm values) can safely acquire it.

## Why this works

**Part A:** a standard Kubernetes `NetworkPolicy` reasons about L3 (IP/identity) and L4 (protocol+port) only — it cannot distinguish `GET /health` from `POST /admin`; both are indistinguishable "TCP port 80 traffic." `CiliumNetworkPolicy` additionally expresses L7 rules: when it includes `rules.http`, Cilium transparently redirects matching traffic through an embedded Envoy proxy on the node, which parses the actual HTTP request and enforces method/path rules before allowing or rejecting (HTTP 403) it, with no change to the application or client. Once any `CiliumNetworkPolicy` selects an endpoint for `Ingress`, that endpoint becomes default-deny — `outsider`, not matching `fromEndpoints` at all, is blocked at L3/L4 before Envoy is even involved, while `caller` issuing `POST /admin` is an allowed *source* but blocked at L7 by Envoy for not matching the `http` rule. **Part B:** WireGuard transparent encryption works independently of any policy, encrypting all pod-to-pod traffic between nodes at the datapath level with no application-level TLS involved. It's a cluster-wide Cilium Helm configuration change, not a namespaced object, so it's a genuinely shared/singleton resource requiring the `cilium-config` lock so two labs never fight over Cilium's Helm values simultaneously. Because wire-level encryption can't easily be proven via packet capture from inside a lab script, verification instead confirms Cilium's own reported state — both the Helm-driven ConfigMap value and the running agent's own status output — rather than assuming a successful `helm upgrade` is proof enough.

## Faster exam-oriented method

Part A: write the single `CiliumNetworkPolicy` combining `fromEndpoints: [{app: caller}]` with `toPorts` L7 `rules.http` for `GET /health` directly — no need to separately test every combination first if the shape is already known. Part B: one `helm upgrade --reuse-values --set encryption.enabled=true --set encryption.type=wireguard`, then check both the ConfigMap value and `cilium-dbg status --brief` in one agent Pod.

## Common mistakes

- Writing two separate `CiliumNetworkPolicy` rules (one for identity, one for HTTP) instead of combining `fromEndpoints` and `toPorts.rules.http` inside a single ingress rule — the task requires them combined so only `caller` requests are even subject to the L7 check.
- Believing a plain Kubernetes `NetworkPolicy` could achieve the method/path restriction — it has no L7 awareness at all; only `CiliumNetworkPolicy`'s `rules.http` can express this.
- Running the Part B `helm upgrade` without first confirming (or trusting `setup.sh`'s) acquisition of the `cilium-config` lock — this is cluster-wide, shared Cilium configuration, and an uncoordinated concurrent change from another lab could conflict.
- Setting other Cilium Helm values beyond `encryption.enabled`/`encryption.type` while upgrading — the requirements explicitly forbid touching any other Helm value.
- Trusting `helm upgrade` exiting successfully as proof WireGuard is active — the task specifically requires confirming both the ConfigMap value *and* a live agent's own status output, since a successful Helm operation doesn't guarantee the running datapath state matches.

## Relevant documentation

- Cilium Network Policy — https://docs.cilium.io/en/stable/security/policy/language/
- Cilium WireGuard transparent encryption — https://docs.cilium.io/en/stable/security/network/encryption-wireguard/
- Cilium troubleshooting — https://docs.cilium.io/en/stable/operations/troubleshooting/
- Kubernetes NetworkPolicies — https://kubernetes.io/docs/concepts/services-networking/network-policies/
