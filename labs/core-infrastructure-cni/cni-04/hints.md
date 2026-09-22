# Hints — CNI-04

## Level 1

Both `client` and `server` are Ready, and the Service exists, so nothing
about object state is wrong. Start by actually trying the request and
seeing what it does:

```bash
CLIENT_POD=$(kubectl -n ckne-cni-04 get pods -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl -n ckne-cni-04 exec "$CLIENT_POD" -- curl -v -m 5 http://server.ckne-cni-04.svc.cluster.local
```

What does curl report — a timeout, a refused connection, or something
else?

## Level 2

Check what's actually listening inside the `server` Pod, in the same
network namespace as `web`:

```bash
kubectl -n ckne-cni-04 exec server -c debug -- ss -tlnp
```

Now compare that against what the Service thinks it should be forwarding
to:

```bash
kubectl -n ckne-cni-04 get svc server -o yaml
```

Is there a port actually listening that matches the Service's
`targetPort`?

## Level 3

Capture packets on the `server` Pod's interface while you retry the
request from `client`, to see it happen live:

```bash
kubectl -n ckne-cni-04 exec server -c debug -- timeout 10 tcpdump -i eth0 -n tcp
```
(in another terminal) re-run the `curl` from Level 1 while that's capturing.

The Service's `targetPort` needs to match the port `ss` showed `web`
actually listening on. Patch the Service accordingly — no change to
`client`, `web`'s container port, or the Deployment is needed.
