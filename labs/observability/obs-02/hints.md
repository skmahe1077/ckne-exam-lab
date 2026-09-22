# Hints — OBS-02

## Level 1

Start with CoreDNS's own logs, then look at Service health in your
namespace:

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100
kubectl -n ckne-obs-02 get pods
kubectl -n ckne-obs-02 get endpoints orders
```

Do the CoreDNS logs mention `orders` or `ckne-obs-02` at all? What does
`READY` show for the `orders` Pods — is it `1/1` or `0/1`?

## Level 2

Confirm DNS actually works, then ask Kubernetes why the Pods aren't Ready:

```bash
kubectl -n ckne-obs-02 run dns-check --image=busybox:1.36 --rm -it --restart=Never \
  -- nslookup orders.ckne-obs-02.svc.cluster.local

kubectl -n ckne-obs-02 describe pod -l app=orders
```

Read the `Events` section — what is the readinessProbe actually checking,
and how often is it failing?

## Level 3

```bash
kubectl -n ckne-obs-02 get deployment orders -o yaml | grep -A4 readinessProbe
```

The probe checks a path that nginx's default config never serves. Compare
it against what a plain `nginx:1.27` container actually responds to on
`/`.
