# Hints — SVC-03

## Level 1

Look at what already exists in the namespace:

```bash
kubectl -n ckne-svc-03 get deployment shop --show-labels
kubectl -n ckne-svc-03 get svc
```

There's no Service yet. What labels does the `shop` Deployment's Pod
template carry — that's what your Service's selector needs to match.

## Level 2

Create the Service (imperatively or via a manifest) with `type:
LoadBalancer`:

```bash
kubectl -n ckne-svc-03 expose deployment shop --name=shop --type=LoadBalancer --port=80 --target-port=80
kubectl -n ckne-svc-03 get svc shop -o wide
```

Watch the `EXTERNAL-IP` column. What controller in this cluster would need
to be running for that to ever change from `<pending>`?

## Level 3

```bash
kubectl -n ckne-svc-03 get svc shop -o jsonpath='{.status.loadBalancer}{"\n"}'
kubectl -n kube-system get pods | grep -i -E 'cloud-controller|metallb' || echo "none found"
```

No cloud-controller-manager or bare-metal LB controller is running in
this cluster, so nothing will ever populate `status.loadBalancer.ingress`.
Don't add labels/annotations chasing a fix that requires a controller.
Instead, confirm the Service's ClusterIP path works with an in-cluster
request — the required labels are still
`app.kubernetes.io/part-of: ckne-hands-on` and
`ckne.openai.com/lab-id: "SVC-03"`.
