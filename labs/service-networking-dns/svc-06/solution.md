# CKNE-SVC-06 — Solution

## Root cause

The `web` Deployment's `readinessProbe` checks `GET /healthz` on port 80, but nginx's default `nginx:1.27` image doesn't serve anything at that path — it 404s. Both containers stay `Running` but never become `Ready`, so neither Pod's address is added to the Service's EndpointSlice as a usable endpoint.

## Investigation process

Start with the Pods, not the Service:

```bash
kubectl -n ckne-svc-06 get pods -l app=web -o wide
```

`STATUS` says `Running`, but `READY` isn't `2/2`. Ask Kubernetes directly what the probe is doing:

```bash
kubectl -n ckne-svc-06 describe pod -l app=web
```

Repeating Events:
```
Warning  Unhealthy  ...  Readiness probe failed: HTTP probe failed with statuscode: 404
```

Check what the probe is actually configured to check:

```bash
kubectl -n ckne-svc-06 get deployment web -o yaml | grep -A6 readinessProbe
# path: /healthz
```

Look at the EndpointSlice while the Pods are still not Ready — this is what "invisible to the Service" looks like at the API level:

```bash
kubectl -n ckne-svc-06 get endpointslice -l kubernetes.io/service-name=web -o yaml
```

## Corrected configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ckne-svc-06
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
            failureThreshold: 2
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

Equivalent inline patch:

```bash
kubectl -n ckne-svc-06 patch deployment web --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

## Verification steps

```bash
kubectl -n ckne-svc-06 rollout status deployment/web
kubectl -n ckne-svc-06 get endpointslice -l kubernetes.io/service-name=web -o yaml
make validate LAB=SVC-06
```

Both endpoint addresses should now appear with `conditions.ready: true`.

## Why this works

A Service's `selector` decides which Pods are *candidates* for traffic, but candidacy alone isn't enough — Kubernetes only routes to Pods that are also Ready. The EndpointSlice controller watches the Service's selector and the matching Pods' status, and each entry's `conditions.ready` is `true` only if the Pod's `Ready` condition is `true`, which itself only becomes true once every container passes its `readinessProbe`. kube-proxy/Cilium program load-balancing rules from the *ready* addresses in the EndpointSlice, not from the Pod list directly — a Pod that's `Running` but fails its readiness probe still exists and is still selected by the label selector, but is either omitted from the EndpointSlice or listed with `conditions.ready: false`, and traffic is never sent to it. Pointing the probe at `/` (which nginx actually serves with 2xx) is what lets the Pods become Ready and their addresses appear in the EndpointSlice as usable endpoints — the Service object itself never needed to change.

## Faster exam-oriented method

`kubectl get pods -l app=web` showing `Running` but not `Ready` is the immediate signal to check probes, not the Service. `kubectl describe pod` names the exact status code; one JSON patch to the probe's `path` fixes it.

## Common mistakes

- Removing the readinessProbe entirely instead of fixing its path — makes the Pod immediately Ready regardless of real health, defeating the purpose of a readiness check and explicitly disallowed by the requirements.
- Modifying the Service's selector or ports while diagnosing — the Service was never the problem; only the probe configuration on the Deployment needed to change.
- Confusing "Pod is Running" with "Pod is Ready" — the two are independent Pod states, and only Ready Pods contribute EndpointSlice entries with `conditions.ready: true`.
- Checking only Pod status (`2/2 Ready`) without also inspecting the actual EndpointSlice object — the task specifically requires confirming the EndpointSlice reflects both Pods with `conditions.ready: true`, not just that the Deployment rolled out successfully.

## Relevant documentation

- Kubernetes EndpointSlices — https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Configure liveness/readiness/startup probes — https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- Container probes — https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes
