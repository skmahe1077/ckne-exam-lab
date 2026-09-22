# Solution — SVC-03

## Diagnosis

There's nothing to diagnose in the sense of "find the bug" — the `shop`
Deployment simply has no Service yet. The exercise is to create the right
kind of Service and correctly interpret its resulting status.

## Fix

Apply the reference Service (see `manifests/expected/service.yaml`):

```bash
kubectl apply -f manifests/expected/service.yaml   # after sed-substituting ${NAMESPACE}/${TASK_ID}
```

or equivalently:

```bash
kubectl -n ckne-svc-03 expose deployment shop --name=shop \
  --type=LoadBalancer --port=80 --target-port=80
kubectl -n ckne-svc-03 label svc shop \
  app.kubernetes.io/part-of=ckne-hands-on 'ckne.openai.com/lab-id=SVC-03'
```

## Verify

```bash
kubectl -n ckne-svc-03 get svc shop -o wide
# TYPE=LoadBalancer, CLUSTER-IP set, EXTERNAL-IP=<pending> (expected —
# no cloud-controller-manager / MetalLB is running in this cluster)

kubectl -n ckne-svc-03 get endpoints shop
# 2 Pod IPs

kubectl -n ckne-svc-03 run verify --image=busybox:1.36 --restart=Never --rm -i \
  --command -- wget -q -T5 -O- http://shop.ckne-svc-03.svc.cluster.local

make validate LAB=SVC-03
```

`EXTERNAL-IP` staying `<pending>` forever is the correct, expected result
here — it does not mean the Service is misconfigured. The Service's
ClusterIP path (and, incidentally, its nodePort) already work exactly like
any other Service type; only the cloud-controller-manager's job of
provisioning a real external load balancer has no implementation in this
cluster.
