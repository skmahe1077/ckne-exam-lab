# Solution — CNI-04

## Diagnosis

1. A request from `client` to the Service times out / hangs:

   ```bash
   CLIENT_POD=$(kubectl -n ckne-cni-04 get pods -l app=client -o jsonpath='{.items[0].metadata.name}')
   kubectl -n ckne-cni-04 exec "$CLIENT_POD" -- curl -v -m 5 http://server.ckne-cni-04.svc.cluster.local
   ```

2. `ss` inside the `server` Pod's shared network namespace shows nginx
   listening only on port 80:

   ```bash
   kubectl -n ckne-cni-04 exec server -c debug -- ss -tlnp
   # LISTEN 0  511  0.0.0.0:80  ...
   ```

3. But the Service is configured with `targetPort: 8080`:

   ```bash
   kubectl -n ckne-cni-04 get svc server -o yaml | grep -A2 ports:
   ```

4. A `tcpdump` capture on `server`'s interface while retrying the request
   shows packets arriving addressed to tcp/8080 and an immediate `RST` —
   nothing is listening there, so the kernel refuses the connection at the
   TCP layer, before nginx (which only knows about port 80) is ever
   involved.

## Fix

Correct the Service's `targetPort` to 80 (see `manifests/expected/server.yaml`
for the full corrected object):

```bash
kubectl -n ckne-cni-04 patch svc server --type=json \
  -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
```

## Verify

```bash
kubectl -n ckne-cni-04 exec "$CLIENT_POD" -- curl -s -o /dev/null -w '%{http_code}\n' \
  http://server.ckne-cni-04.svc.cluster.local
make validate LAB=CNI-04
```

Every object involved (`client`, `web`, `debug`, the Service) was valid and
Ready the whole time — the bug only existed in the relationship between two
numbers (the Service's `targetPort` and the port nginx actually binds to),
which is exactly why it required looking at real traffic to find.
