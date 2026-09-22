# CKNE-OBS-02 — Solution

## Root cause

`orders`'s readinessProbe checks `GET /healthz`, but the nginx-based container only ever serves `/`. The probe never succeeds, so the Pods stay `Running`-but-`NotReady` forever, the `orders` Service never gets any Endpoints, and every request fails — even though DNS resolution of the Service name works fine.

## Investigation process

Start with CoreDNS's own logs:

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100
```

Nothing related to `orders` or `ckne-obs-02` — no SERVFAILs, no forwarding errors. Confirm DNS actually works independently:

```bash
kubectl -n ckne-obs-02 run dns-check --image=busybox:1.36 --rm -it --restart=Never \
  -- nslookup orders.ckne-obs-02.svc.cluster.local
# Name:   orders.ckne-obs-02.svc.cluster.local
# Address: 10.96.x.x
```

DNS resolves fine — ruled out. Having ruled out DNS, inspect Endpoints:

```bash
kubectl -n ckne-obs-02 get pods
kubectl -n ckne-obs-02 get endpoints orders
```

Empty `ENDPOINTS`, and `orders` Pods show `0/1 Running` (not `CrashLoopBackOff` — the container is alive, just never marked Ready). Ask why:

```bash
kubectl -n ckne-obs-02 describe pod -l app=orders
```

Repeated `Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 404` — the probe checks `GET /healthz`, which a default `nginx:1.27` image never serves.

## Corrected configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders
  namespace: ckne-obs-02
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orders
  template:
    metadata:
      labels:
        app: orders
    spec:
      containers:
        - name: orders
          image: nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
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
kubectl -n ckne-obs-02 patch deployment orders --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

## Verification steps

```bash
kubectl -n ckne-obs-02 rollout status deployment/orders
kubectl -n ckne-obs-02 get endpoints orders
make validate LAB=OBS-02
```

## Why this works

DNS and Service health are two separate, independently-failing layers. A Service's DNS record is created the moment the Service object exists in the API — it does not depend on the Service having any healthy backends, which is why DNS resolution succeeds even while `orders` is completely broken. Endpoints/EndpointSlices answer a different question: which Pod IPs is the Service currently allowed to route to? Only Pods that are Ready — passing their readinessProbe, not merely Running — are included. A Pod stuck `0/1 Running` because its readinessProbe checks a path the container never serves silently drops out of the backend set, with no Event on the Service itself and no DNS error anywhere. Correcting the probe path to `/` (which nginx actually serves) is what lets the Pods become Ready and the Service pick up Endpoints again — CoreDNS and the Service object were never the problem.

## Faster exam-oriented method

`kubectl get pods -n ckne-obs-02` showing `0/1 Running` (not `CrashLoopBackOff`) plus `kubectl get endpoints orders` showing empty is the signature of a readiness-probe failure, not a DNS or networking issue — skip straight to `kubectl describe pod -l app=orders` for the probe's exact failure reason and patch the path.

## Common mistakes

- Assuming "nothing reaches the Service" implies DNS is broken and spending time on CoreDNS logs/config without first confirming (or ruling out) that assumption directly — CoreDNS was never the problem here, and the task specifically tests recognizing that a working DNS record doesn't guarantee a working backend.
- Confusing `Running` with `Ready` — a Pod can be alive and serving traffic on its own port while still failing its readinessProbe on a different, misconfigured path, which is exactly this bug.
- Modifying CoreDNS or its Corefile while diagnosing — explicitly out of scope and never the actual fault.
- Fixing the symptom by removing the readinessProbe entirely instead of correcting its path — technically makes Endpoints populate immediately, but removes a legitimate health check rather than fixing the misconfiguration, which is a larger change than necessary.

## Relevant documentation

- DNS debugging resolution — https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
- DNS for Services and Pods — https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Container probes — https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes
- Discovering Services — https://kubernetes.io/docs/concepts/services-networking/service/#discovering-services
