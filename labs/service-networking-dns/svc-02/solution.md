# CKNE-SVC-02 — Solution

## Root cause

Service `web`'s `targetPort` is `8080`, but nginx inside the `web` Pods only listens on `80`. `type: NodePort`, the `nodePort` allocation, the selector, and Endpoints all populate correctly (Kubernetes never verifies a container is actually listening on `targetPort`) — but every connection through the Service fails at the last hop.

## Investigation process

Start with the object-level view — it looks mostly correct:

```bash
kubectl -n ckne-svc-02 get svc web
kubectl -n ckne-svc-02 get endpoints web
# type NodePort, nodePort allocated, 2 Endpoint IPs present
```

Look one hop further, at the Pod itself:

```bash
kubectl -n ckne-svc-02 get svc web -o jsonpath='{.spec.ports[0].targetPort}{"\n"}'
kubectl -n ckne-svc-02 get deployment web -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}{"\n"}'
```

`targetPort` (8080) doesn't match `containerPort` (80).

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ckne-svc-02
  labels:
    app: web
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Equivalent inline patch:

```bash
kubectl -n ckne-svc-02 patch svc web --type=merge \
  -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":80}]}}'
```

## Verification steps

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl -n ckne-svc-02 get svc web -o jsonpath='{.spec.ports[0].nodePort}')
kubectl -n ckne-svc-02 run verify --image=busybox:1.36 --restart=Never --rm -i \
  --command -- wget -q -T5 -O- "http://${NODE_IP}:${NODE_PORT}"
make validate LAB=SVC-02
```

Because the NodePort range in this cluster's security group is only open to traffic originating inside the cluster, this verification must run from an in-cluster Pod against a node's private IP — not from your laptop.

## Why this works

`type: NodePort` builds on top of `ClusterIP` — kube-proxy/Cilium opens the same port number on every node and forwards traffic arriving there to the Service's ClusterIP, which then load-balances across `targetPort` on the matching Pods, exactly like a ClusterIP Service does internally. That chain means a NodePort Service can fail for any of the same reasons a ClusterIP Service can (bad selector, wrong `targetPort`), and `targetPort` is the independent last hop from the Service to the container — even with `type: NodePort` correctly configured and Endpoints correctly populated, a wrong `targetPort` breaks that final leg exactly as it would for a plain ClusterIP Service. Correcting `targetPort` to `80` is what lets traffic that already correctly reaches the node and the Service actually land on nginx's real listening port.

## Faster exam-oriented method

`kubectl get svc web -o jsonpath='{.spec.ports[0]}'` next to `kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].ports}'` — a `targetPort`/`containerPort` mismatch is visible in two commands. One `kubectl patch --type=merge` fixes it.

## Common mistakes

- Testing from outside the cluster (e.g. a laptop) and concluding the Service is broken because the request never arrives — the security group deliberately only allows NodePort traffic from inside the cluster's own network; this is expected and not the bug, per the task's explicit framing.
- Assuming a NodePort with `nodePort` allocated and Endpoints populated must be fully working — neither of those checks anything about whether `targetPort` matches a real listening port on the Pod.
- Changing `port` instead of `targetPort` — `port` (the Service's own port, used internally by ClusterIP-style routing) was already correct at 80; the mismatch is specifically in `targetPort`, the hop to the container.
- Reaching for security-group/firewall changes to "open up" connectivity — the security group's NodePort restriction is intentional and unrelated to this bug; the fix is entirely inside the Service's `targetPort`.

## Relevant documentation

- Kubernetes Services (NodePort) — https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport
- Debugging Services — https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
