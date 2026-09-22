# Hints — ATM-06

## Level 1

Confirm the control-plane precondition first, then look at your own
namespace:

```bash
kubectl -n kube-system get deployment clustermesh-apiserver
kubectl -n kube-system get svc clustermesh-apiserver
kubectl -n ckne-atm-06 get svc catalog -o yaml
```

Does `catalog`'s `metadata.annotations` mention anything about
`service.cilium.io`?

## Level 2

Check what the four mesh TLS Secrets actually contain (not just that they
exist):

```bash
kubectl -n kube-system get secret clustermesh-apiserver-server-cert -o jsonpath='{.data}' | tr ',' '\n'
```

You should see `tls.crt`, `tls.key`, and `ca.crt` keys with non-empty
base64 data. This confirms the control-plane precondition is genuinely
satisfied, not just that the Secret object exists.

## Level 3

Annotate the `catalog` Service:

```bash
kubectl -n ckne-atm-06 annotate service catalog service.cilium.io/global="true"
```

Then re-check:

```bash
kubectl -n ckne-atm-06 get svc catalog -o jsonpath='{.metadata.annotations}{"\n"}'
```

Nothing about the Deployment, the selector, or `clustermesh-apiserver`
itself needs to change — only this one annotation.
