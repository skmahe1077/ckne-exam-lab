# CKNE-SVC-04 — Solution

## Root cause

Service `docs`'s `spec.externalName` points at `kubernetes-docs.invalid.nonexistent-ckne-lab-domain.test` — a domain that was never registered. CoreDNS's CNAME rewrite leads nowhere, so any lookup of the Service's DNS name fails with NXDOMAIN.

## Investigation process

```bash
kubectl -n ckne-svc-04 get svc docs -o yaml
```

`spec.externalName` doesn't look like a real public domain. Confirm the failure from inside the cluster:

```bash
kubectl -n ckne-svc-04 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
  --command -- nslookup docs.ckne-svc-04.svc.cluster.local
# ** server can't find ...: NXDOMAIN
```

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: docs
  namespace: ckne-svc-04
spec:
  type: ExternalName
  externalName: kubernetes.io
```

Equivalent inline patch:

```bash
kubectl -n ckne-svc-04 patch svc docs --type=merge \
  -p '{"spec":{"externalName":"kubernetes.io"}}'
```

## Verification steps

```bash
kubectl -n ckne-svc-04 run dns-check --image=busybox:1.36 --restart=Never --rm -i \
  --command -- nslookup docs.ckne-svc-04.svc.cluster.local
# Name should resolve, with a CNAME to kubernetes.io in the chain

make validate LAB=SVC-04
```

## Why this works

`type: ExternalName` is the odd one out among Service types: no selector, no Endpoints, no ClusterIP, and kube-proxy/Cilium's service-proxy layer never touches it — it exists purely as a DNS alias. When CoreDNS's `kubernetes` plugin sees a query for `docs.ckne-svc-04.svc.cluster.local` against a Service with `type: ExternalName`, it answers with a CNAME record pointing at `spec.externalName` instead of an A/AAAA record; the resolver then follows that CNAME like any other DNS client, and CoreDNS's `forward` plugin resolves the rest upstream. Pointing `externalName` at a real, stable public domain (`kubernetes.io`) is what makes that CNAME chain actually resolve — because there's no proxying involved at all, this is purely a DNS-level fix with no selector, ports, or Endpoints ever needed.

## Faster exam-oriented method

`kubectl get svc docs -o jsonpath='{.spec.externalName}'` — an obviously-fake or unregistered-looking domain is the entire diagnosis. One `kubectl patch --type=merge` swapping in a real domain fixes it; re-run `nslookup` once to confirm the CNAME resolves through.

## Common mistakes

- Adding a `selector` or `ports` to try to "fix" connectivity — `ExternalName` Services use neither; the task explicitly calls out this bug is purely a DNS target problem, not a proxy/routing one.
- Changing the Service's `type`, `name`, or namespace instead of just `externalName` — the minimum fix is the DNS target value alone.
- Assuming NXDOMAIN means CoreDNS itself is broken and investigating the CoreDNS Deployment/Corefile — CoreDNS is functioning correctly here; it's faithfully reporting that the configured `externalName` genuinely doesn't exist.
- Confirming only that `kubectl get svc docs` shows the new `externalName` value without re-running `nslookup` from inside the cluster — the task specifically requires proving CoreDNS actually performed the CNAME rewrite, not just that the object was edited.

## Relevant documentation

- Kubernetes Services (ExternalName) — https://kubernetes.io/docs/concepts/services-networking/service/#externalname
- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
