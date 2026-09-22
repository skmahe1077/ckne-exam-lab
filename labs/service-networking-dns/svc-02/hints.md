# Hints — SVC-02

## Level 1

Start with the object-level view — it will look mostly correct:

```bash
kubectl -n ckne-svc-02 get svc web
kubectl -n ckne-svc-02 get endpoints web
```

Type is NodePort, a nodePort is allocated, Endpoints has 2 IPs. So why
does traffic still fail? Look one hop further, at the Pod itself.

## Level 2

```bash
kubectl -n ckne-svc-02 get svc web -o jsonpath='{.spec.ports[0]}{"\n"}'
kubectl -n ckne-svc-02 get deployment web -o jsonpath='{.spec.template.spec.containers[0].ports}{"\n"}'
```

Compare `targetPort` on the Service to `containerPort` on the Pod
template. Do they match?

## Level 3

```bash
kubectl -n ckne-svc-02 patch svc web --type=merge -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":80}]}}'
```

Then find a node's internal IP (`kubectl get nodes -o wide`) and test the
nodePort from a Pod inside the cluster against `<node-IP>:<nodePort>`.
