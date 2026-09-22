# SVC-05 — Headless Services and StatefulSet DNS

**Domain:** Service Networking and DNS · **Difficulty:** intermediate · **Est. time:** 20 min

A `web` StatefulSet is 3/3 Ready and its governing Service load-balances
fine, but per-Pod DNS names like `web-0.web.ckne-svc-05.svc.cluster.local`
don't resolve to each Pod's own IP. Make the Service headless so CoreDNS
creates the per-Pod records StatefulSets rely on.

```bash
make start    LAB=SVC-05
make validate LAB=SVC-05
make cleanup  LAB=SVC-05
make reset    LAB=SVC-05

make learn LAB=SVC-05              # concept + task + quick reference
make exam  LAB=SVC-05              # task only, no hints/solution
make hint  LAB=SVC-05 LEVEL=1
make solution LAB=SVC-05
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
