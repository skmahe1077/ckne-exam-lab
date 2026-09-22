# CKNE-SVC-01 — Solution

## Root cause

Service `api`'s `spec.selector` is `app: apiserver`, a label no Pod in the namespace actually carries — the `api` Deployment's Pods are labeled `app: api`. The Service object exists and looks fine at a glance, but it has zero Endpoints, so no traffic ever reaches a Pod.

## Investigation process

Confirm the Pods themselves are healthy, then look at what's actually backing the Service:

```bash
kubectl -n ckne-svc-01 get deployment api
kubectl -n ckne-svc-01 get endpoints api
# api   <none>
```

Compare what the Service is looking for against what the Pods actually carry:

```bash
kubectl -n ckne-svc-01 get svc api -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n ckne-svc-01 get pods --show-labels
```

The selector (`app: apiserver`) doesn't match the Pod template's actual label (`app: api`).

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: ckne-svc-01
  labels:
    app: api
spec:
  type: ClusterIP
  selector:
    app: api
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Equivalent inline patch:

```bash
kubectl -n ckne-svc-01 patch svc api --type=merge -p '{"spec":{"selector":{"app":"api"}}}'
```

## Verification steps

```bash
kubectl -n ckne-svc-01 get endpoints api
make validate LAB=SVC-01
```

Endpoints should now list both Pod IPs on port 80, and a request to the Service's ClusterIP should succeed.

## Why this works

A Service never proxies to "the Deployment" — it has no idea Deployments exist. It only knows about Pods matching `spec.selector`; the Endpoints controller continuously watches for Pods whose labels match that selector and writes their IP:port pairs into an Endpoints/EndpointSlice object, and kube-proxy/Cilium programs actual forwarding rules purely from that list, never from the selector directly. A Service whose selector matches zero Pods is a perfectly valid, healthy-looking API object — it has a ClusterIP, `kubectl describe` shows the selector — but `kubectl get endpoints` shows `<none>` and every connection fails. Correcting the selector to `app: api` is what lets the Endpoints controller start matching the real Pods and populating the Endpoints list, which is the only thing kube-proxy/Cilium actually route traffic from.

## Faster exam-oriented method

`kubectl get endpoints api` showing `<none>` is the instant signal — go straight to comparing `kubectl get svc api -o jsonpath='{.spec.selector}'` against `kubectl get pods --show-labels`. One `kubectl patch --type=merge` fixes the selector.

## Common mistakes

- Relabeling the Deployment's Pods to match the Service's (wrong) selector instead of fixing the Service — the requirements explicitly call for fixing the Service, not the Pods, and relabeling Pods is a larger, less minimal change.
- Assuming a Service with an assigned ClusterIP and no visible errors must be working — Kubernetes never validates that a selector matches any real Pod; a zero-match selector produces no error anywhere, only an empty Endpoints list.
- Stopping at "Endpoints is now non-empty" without confirming a real request actually succeeds — the task specifically requires end-to-end success, not just a populated Endpoints list (see SVC-06 for a case where Endpoints exist but readiness still matters).
- Checking `targetPort` when the actual bug is the selector, or vice versa — both are independent failure modes for a Service (selector affects whether Endpoints populate at all; `targetPort` affects whether traffic reaches a real listening port even with correct Endpoints); this lab's fault is purely the selector.

## Relevant documentation

- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
- Debugging Services — https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
