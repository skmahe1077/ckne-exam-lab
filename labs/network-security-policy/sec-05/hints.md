# Hints — SEC-05

## Level 1

Check what's currently protecting `backend`, and what labels each client
carries:

```bash
kubectl -n ckne-sec-05 get networkpolicy
kubectl get namespace ckne-sec-05-clients --show-labels
kubectl -n ckne-sec-05-clients get pods --show-labels
kubectl -n ckne-sec-05 get pods --show-labels
```

## Level 2

Notice `worker-a` is in the trusted namespace but has the wrong role, and
`rogue-frontend` has the right-looking role but is in the wrong namespace.
Both must be blocked at the same time `frontend-a` is allowed. A policy
that allows either condition alone (two separate `from` list entries) will
incorrectly let one of them through — test both after you write your
policy, don't just test `frontend-a`.

## Level 3

Use exactly ONE `from` list element with BOTH `namespaceSelector` and
`podSelector` set on it (not two separate list elements) — see
`manifests/expected/allow-trusted-frontend.yaml`. Re-read the "Behavior of
to and from selectors" section of the NetworkPolicy docs if the YAML
structure isn't clicking.
