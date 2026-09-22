# Hints — SVC-01

## Level 1

Confirm the Pods themselves are healthy, then look at what's actually
backing the Service:

```bash
kubectl -n ckne-svc-01 get deployment api
kubectl -n ckne-svc-01 get endpoints api
```

Is the Endpoints list empty?

## Level 2

Compare what the Service is looking for against what the Pods actually
carry:

```bash
kubectl -n ckne-svc-01 get svc api -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n ckne-svc-01 get pods --show-labels
```

Do the two sets of labels match?

## Level 3

```bash
kubectl -n ckne-svc-01 patch svc api --type=merge -p '{"spec":{"selector":{"app":"api"}}}'
kubectl -n ckne-svc-01 get endpoints api
```

Once the selector matches the Pods' real `app` label, Endpoints should
populate immediately and traffic should flow.
