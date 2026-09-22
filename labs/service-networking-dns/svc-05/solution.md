# CKNE-SVC-05 — Solution

## Root cause

The `web` Service governing the StatefulSet is a normal ClusterIP Service, not headless — `spec.clusterIP` is a real IP, not `None`. It correctly selects the StatefulSet's Pods and load-balances across them, but because it isn't headless, CoreDNS never creates the per-Pod DNS records (`<pod>.web.ckne-svc-05.svc.cluster.local`) that StatefulSet Pods rely on for stable per-replica addressing.

## Investigation process

```bash
kubectl -n ckne-svc-05 get statefulset web
# READY 3/3
```

The StatefulSet is healthy — not the problem. Check the governing Service:

```bash
kubectl -n ckne-svc-05 get svc web -o jsonpath='{.spec.clusterIP}{"\n"}'
```

A real IP, not `None`. Try resolving a specific Pod's DNS name:

```bash
kubectl -n ckne-svc-05 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
  --command -- nslookup web-0.web.ckne-svc-05.svc.cluster.local
```

Because the Service isn't headless, CoreDNS never publishes per-Pod records for it at all — this lookup fails outright (NXDOMAIN), even though the StatefulSet and its Pods are completely healthy.

## Corrected configuration

`clusterIP` is immutable once a Service is created — it must be deleted and recreated as headless:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ckne-svc-05
  labels:
    app: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
```

```bash
kubectl -n ckne-svc-05 delete svc web
kubectl apply -f labs/service-networking-dns/svc-05/manifests/expected/service.yaml
```

## Verification steps

```bash
kubectl -n ckne-svc-05 get svc web -o jsonpath='{.spec.clusterIP}{"\n"}'
# None

for i in 0 1 2; do
  kubectl -n ckne-svc-05 run dns-check-$i --image=busybox:1.36 --restart=Never --rm -i \
    --command -- nslookup web-$i.web.ckne-svc-05.svc.cluster.local
  kubectl -n ckne-svc-05 get pod web-$i -o jsonpath='{.status.podIP}{"\n"}'
done

make validate LAB=SVC-05
```

Each `web-<N>.web.ckne-svc-05.svc.cluster.local` lookup should now return exactly that Pod's own `status.podIP`.

## Why this works

A regular ClusterIP Service gives one stable virtual IP that load-balances across all matching Pods — fine when the caller doesn't care which specific backend answers. A StatefulSet is built for the opposite case: each Pod has a stable identity, and other components sometimes need to reach one specific replica, which a shared VIP can't express. Setting `clusterIP: None` turns the Service headless: Kubernetes no longer allocates any ClusterIP, and CoreDNS's `kubernetes` plugin changes what it returns entirely — a headless Service's name resolves to the *set* of all backing Pod IPs directly, and CoreDNS additionally publishes one record per Pod (`<pod-name>.<svc>.<namespace>.svc.cluster.local` → that individual Pod's own IP). The StatefulSet controller gives each Pod its predictable `<name>-<ordinal>` hostname; the headless governing Service referenced via `spec.serviceName` is what turns those hostnames into real, resolvable per-Pod DNS records. None of this depends on the StatefulSet or Pods themselves — a non-headless Service leaves everything else looking perfectly healthy while silently never creating the records StatefulSet peer addressing relies on.

## Faster exam-oriented method

`kubectl get svc web -o jsonpath='{.spec.clusterIP}'` — anything other than `None` on a StatefulSet's governing Service is the entire diagnosis. Delete and recreate with `clusterIP: None` immediately; no need to investigate the StatefulSet or Pods at all.

## Common mistakes

- Trying `kubectl patch`/`kubectl edit` to change `clusterIP` to `None` on the existing Service — `clusterIP` is immutable after creation; the object must be deleted and recreated.
- Investigating the StatefulSet, its Pods, or their readiness while diagnosing — all are healthy preconditions; the fault is entirely in the governing Service's type.
- Forgetting to keep the same Service name, namespace, selector, and port when recreating — the StatefulSet's `spec.serviceName: web` reference depends on a Service with that exact name existing, and the selector must still match the StatefulSet's Pods for Endpoints (and thus per-Pod DNS) to populate.
- Assuming a failed `nslookup` for `web-0...` means the Pod itself is unreachable or unhealthy — the Pod's own connectivity is fine; only the DNS record for it was never being created.

## Relevant documentation

- Headless Services — https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
- StatefulSet stable network identity — https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#stable-network-id
- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
