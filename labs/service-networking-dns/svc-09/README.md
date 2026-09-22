# SVC-09 — Gateway API: GatewayClass, Gateway, HTTPRoute

**Domain:** Service Networking and DNS · **Difficulty:** advanced · **Est. time:** 30 min

No `Gateway` or `HTTPRoute` exists yet for the `web` backend. Author both
from scratch, referencing the shared, cluster-wide `GatewayClass` named
`cilium` by name only, and prove a real HTTP request reaches `web` through
the Gateway.

```bash
make start    LAB=SVC-09
make validate LAB=SVC-09
make cleanup  LAB=SVC-09
make reset    LAB=SVC-09

make learn LAB=SVC-09              # concept + task + quick reference
make exam  LAB=SVC-09              # task only, no hints/solution
make hint  LAB=SVC-09 LEVEL=1
make solution LAB=SVC-09
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
