# SVC-06 — EndpointSlices and Readiness

**Domain:** Service Networking and DNS · **Difficulty:** intermediate · **Est. time:** 20 min

A `web` Deployment's Pods are `Running` but never become Ready, so the
`web` Service delivers no traffic. Diagnose the readiness probe, fix it,
and confirm the Service's EndpointSlice reflects both Pods as ready
endpoints.

```bash
make start    LAB=SVC-06
make validate LAB=SVC-06
make cleanup  LAB=SVC-06
make reset    LAB=SVC-06

make learn LAB=SVC-06              # concept + task + quick reference
make exam  LAB=SVC-06              # task only, no hints/solution
make hint  LAB=SVC-06 LEVEL=1
make solution LAB=SVC-06
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
