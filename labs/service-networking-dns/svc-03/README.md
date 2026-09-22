# SVC-03 — LoadBalancer Services

**Domain:** Service Networking and DNS · **Difficulty:** intermediate · **Est. time:** 20 min

A `shop` Deployment has no Service yet. Create a `type: LoadBalancer`
Service for it, and understand why `EXTERNAL-IP` stays `<pending>` on this
cluster (no cloud provider integration) while the Service still routes
traffic correctly via its ClusterIP.

```bash
make start    LAB=SVC-03
make validate LAB=SVC-03
make cleanup  LAB=SVC-03
make reset    LAB=SVC-03

make learn LAB=SVC-03              # concept + task + quick reference
make exam  LAB=SVC-03              # task only, no hints/solution
make hint  LAB=SVC-03 LEVEL=1
make solution LAB=SVC-03
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
