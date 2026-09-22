# Solution — SVC-02

## Diagnosis

1. The Service object looks healthy at first glance:

   ```bash
   kubectl -n ckne-svc-02 get svc web
   kubectl -n ckne-svc-02 get endpoints web
   # type NodePort, nodePort allocated, 2 Endpoint IPs present
   ```

2. But the Service's `targetPort` (8080) does not match the port nginx
   actually listens on in the `web` Pods (80):

   ```bash
   kubectl -n ckne-svc-02 get svc web -o jsonpath='{.spec.ports[0].targetPort}{"\n"}'
   kubectl -n ckne-svc-02 get deployment web -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}{"\n"}'
   ```

   Kubernetes never validates that a container is actually listening on
   `targetPort` — Endpoints populate from Pod IPs + the Service's declared
   `targetPort` regardless, so this class of bug produces healthy-looking
   Endpoints with completely broken connectivity.

## Fix

Correct `targetPort` to 80 (see `manifests/expected/service.yaml` for the
full corrected object):

```bash
kubectl -n ckne-svc-02 patch svc web --type=merge \
  -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":80}]}}'
```

## Verify

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl -n ckne-svc-02 get svc web -o jsonpath='{.spec.ports[0].nodePort}')
kubectl -n ckne-svc-02 run verify --image=busybox:1.36 --restart=Never --rm -i \
  --command -- wget -q -T5 -O- "http://${NODE_IP}:${NODE_PORT}"
make validate LAB=SVC-02
```

Because the NodePort range in this cluster's security group is only open
to traffic originating inside the cluster, this verification must run from
an in-cluster Pod against a node's private IP — not from your laptop.
