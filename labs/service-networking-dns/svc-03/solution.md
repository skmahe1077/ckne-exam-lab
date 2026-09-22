# CKNE-SVC-03 — Solution

## Root cause

There's no bug to find here — the `shop` Deployment simply has no Service yet. The exercise is to create the right kind of Service and correctly interpret its resulting status, since this bare kubeadm cluster has no cloud-controller-manager or bare-metal LB controller (MetalLB, etc.) watching `LoadBalancer` Services.

## Investigation process

Look at what already exists in the namespace:

```bash
kubectl -n ckne-svc-03 get deployment shop --show-labels
kubectl -n ckne-svc-03 get svc
```

No Service exists yet. Confirm no LoadBalancer controller is running, so you know what to expect once created:

```bash
kubectl -n kube-system get pods | grep -i -E 'cloud-controller|metallb' || echo "none found"
```

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: shop
  namespace: ckne-svc-03
  labels:
    app: shop
    app.kubernetes.io/part-of: ckne-hands-on
    ckne.openai.com/lab-id: "SVC-03"
spec:
  type: LoadBalancer
  selector:
    app: shop
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Equivalent imperative commands:

```bash
kubectl -n ckne-svc-03 expose deployment shop --name=shop \
  --type=LoadBalancer --port=80 --target-port=80
kubectl -n ckne-svc-03 label svc shop \
  app.kubernetes.io/part-of=ckne-hands-on 'ckne.openai.com/lab-id=SVC-03'
```

## Verification steps

```bash
kubectl -n ckne-svc-03 get svc shop -o wide
# TYPE=LoadBalancer, CLUSTER-IP set, EXTERNAL-IP=<pending> (expected)

kubectl -n ckne-svc-03 get endpoints shop
# 2 Pod IPs

kubectl -n ckne-svc-03 run verify --image=busybox:1.36 --restart=Never --rm -i \
  --command -- wget -q -T5 -O- http://shop.ckne-svc-03.svc.cluster.local

make validate LAB=SVC-03
```

## Why this works

`type: LoadBalancer` is a strict superset of `type: NodePort`, itself a superset of `type: ClusterIP`. Creating a LoadBalancer Service always allocates a ClusterIP and a nodePort on every node exactly like the other Service types — that provisioning is core Kubernetes and works identically regardless of environment. What's different is the *additional* step: Kubernetes writes a request for an external load balancer into the Service object and waits for a cloud-controller-manager or a bare-metal LB controller to notice and provision a real external IP, writing it back into `status.loadBalancer.ingress`. That provisioning step is not part of core Kubernetes at all — it's entirely delegated to whatever controller watches LoadBalancer Services, and this bare kubeadm cluster has none running. Nothing is broken: the API server accepted the Service, kube-proxy/Cilium programmed the ClusterIP and nodePort paths correctly, and `EXTERNAL-IP` staying `<pending>` forever is the correct signal to recognize on this specific cluster, not a defect to chase.

## Faster exam-oriented method

`kubectl expose deployment shop --name=shop --type=LoadBalancer --port=80 --target-port=80` creates the Service in one command; add the two required labels with `kubectl label`. Confirm via ClusterIP, not by waiting on `EXTERNAL-IP`.

## Common mistakes

- Trying to install or configure MetalLB/cloud-controller-manager to make `EXTERNAL-IP` populate — explicitly out of scope; that would modify shared cluster state and isn't what this lab tests.
- Treating `EXTERNAL-IP: <pending>` as a failure and repeatedly re-applying/editing the Service to "fix" it — the Service manifest is already entirely correct; the pending state is expected and validate.sh checks for exactly that, not for a real external IP.
- Verifying only that the Service object exists without confirming it actually routes traffic via ClusterIP — the task specifically requires proving end-to-end connectivity works despite the missing external IP.
- Forgetting the required labels (`app.kubernetes.io/part-of`, `ckne.openai.com/lab-id`) when creating the Service imperatively via `kubectl expose`, which doesn't carry over Deployment labels automatically.

## Relevant documentation

- Kubernetes Services (LoadBalancer) — https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer
- Debugging Services — https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
