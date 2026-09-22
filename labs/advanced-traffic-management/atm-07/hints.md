# Hints — ATM-07

## Level 1

Confirm the control-plane precondition first, then look at the Service's
current annotations:

```bash
kubectl -n kube-system get deployment clustermesh-apiserver
kubectl -n ckne-atm-07 get svc pricing -o jsonpath='{.metadata.annotations}{"\n"}'
```

`global` and `shared` should already say `"true"`. What does `affinity`
say?

## Level 2

Re-read the required policy in task.md carefully: "prefer local backends,
fail over to remote only if local is unhealthy." Which of the three
`service.cilium.io/affinity` values (`none`, `local`, `remote`) expresses
that? Which one is currently set?

## Level 3

```bash
kubectl -n ckne-atm-07 annotate service pricing service.cilium.io/affinity="local" --overwrite
kubectl -n ckne-atm-07 get svc pricing -o jsonpath='{.metadata.annotations}{"\n"}'
```

`global` and `shared` don't need to change — only `affinity`.
