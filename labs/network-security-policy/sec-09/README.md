# SEC-09 — TLS Certificates with cert-manager and ServiceAccount Identity

**Domain:** Network Security and Policy · **Difficulty:** advanced · **Est. time:** 35 min

Two independent sub-tasks in `ckne-sec-09`. Part A: create a namespace-scoped
self-signed `Issuer` and a `Certificate` for the `backend` Service, and
confirm cert-manager actually issues it (a real `tls.crt`/`tls.key` in the
Secret, `Certificate` reporting `Ready: True`). Part B: get the
`backend-workload` Deployment to run under its intended, non-default
`ServiceAccount` (`backend-identity`).

```bash
make start    LAB=SEC-09
make validate LAB=SEC-09
make cleanup  LAB=SEC-09
make reset    LAB=SEC-09

make learn LAB=SEC-09
make exam  LAB=SEC-09
make hint  LAB=SEC-09 LEVEL=1
make solution LAB=SEC-09
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
