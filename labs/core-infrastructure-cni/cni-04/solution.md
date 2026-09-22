# CKNE-CNI-04 — Solution

## Root cause

Service `server`'s `targetPort` is `8080`, but nginx inside the `web` container only listens on port `80`. Every object (`client`, `web`, `debug`, the Service) is valid and Ready — the bug only exists in the relationship between two numbers, invisible to `kubectl get`/`describe`.

## Investigation process

A request from `client` to the Service times out / hangs:

```bash
CLIENT_POD=$(kubectl -n ckne-cni-04 get pods -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl -n ckne-cni-04 exec "$CLIENT_POD" -- curl -v -m 5 http://server.ckne-cni-04.svc.cluster.local
```

Check what's actually listening inside `server`'s shared network namespace, from the `debug` sidecar:

```bash
kubectl -n ckne-cni-04 exec server -c debug -- ss -tlnp
# LISTEN 0  511  0.0.0.0:80  ...
```

Compare against what the Service is configured to forward to:

```bash
kubectl -n ckne-cni-04 get svc server -o yaml | grep -A2 ports:
# targetPort: 8080
```

Confirm on the wire — capture on `server`'s interface while retrying the request from `client`:

```bash
kubectl -n ckne-cni-04 exec server -c debug -- timeout 10 tcpdump -i eth0 -n tcp
```

Packets arrive addressed to tcp/8080 and get an immediate `RST` — nothing is listening there, so the kernel refuses the connection at the TCP layer before nginx (which only knows about port 80) is ever involved.

## Corrected configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: server
  namespace: ckne-cni-04
  labels:
    app: server
spec:
  selector:
    app: server
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Equivalent inline patch:

```bash
kubectl -n ckne-cni-04 patch svc server --type=json \
  -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
```

## Verification steps

```bash
kubectl -n ckne-cni-04 exec "$CLIENT_POD" -- curl -s -o /dev/null -w '%{http_code}\n' \
  http://server.ckne-cni-04.svc.cluster.local
make validate LAB=CNI-04
```

## Why this works

`kubectl get pods`/`get svc` only report what Kubernetes *intends* — a Pod being Ready means its containers started and passed whatever probes were defined, and a Service existing means the object was accepted by the API server; neither tells you whether traffic actually flows end-to-end. Between "the objects look correct" and "the traffic works" sits the real network path, and only tools that show what's *actually happening* — `ss -tlnp` for real listening sockets, `tcpdump` for real packets on the wire — can catch a `targetPort`/actual-listen-port mismatch like this one. Correcting `targetPort` to `80` makes the Service forward to the port nginx genuinely listens on, closing the gap between the YAML and the running process. Because `debug` shares `web`'s network namespace, running these tools in the sidecar sees exactly the same sockets and packets `web` itself would.

## Faster exam-oriented method

`kubectl exec server -c debug -- ss -tlnp` next to `kubectl get svc server -o jsonpath='{.spec.ports[0].targetPort}'` — a listening port that doesn't match `targetPort` is the entire diagnosis, no `tcpdump` strictly required once you've spotted it (though it confirms the `RST` behavior on the wire). One JSON patch fixes the Service.

## Common mistakes

- Treating both `client` and `server` being Ready as proof the connectivity issue must be elsewhere (DNS, NetworkPolicy, CNI) — Pod readiness says nothing about whether a Service's `targetPort` actually matches a real listening socket.
- Changing `web`'s `containerPort` instead of the Service's `targetPort` — `containerPort` is documentation only and doesn't change what nginx actually binds to; the real fix must target the Service, matching it to nginx's actual listening port.
- Adding a second container port or a second Service to work around the mismatch instead of fixing the existing `targetPort` — explicitly disallowed by the requirements and not the minimal fix.
- Skipping `ss`/`tcpdump` and guessing at the fix from the YAML alone — the task specifically requires confirming what's on the wire, since the Service and Endpoints objects look completely valid on their own.

## Relevant documentation

- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
- Debugging Services — https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- Debugging Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
