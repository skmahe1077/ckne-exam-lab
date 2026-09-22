# SVC-04 — ExternalName Services

**Domain:** Service Networking and DNS · **Difficulty:** intermediate · **Est. time:** 15 min

A `docs` ExternalName Service points at a domain that doesn't exist, so it
resolves to nothing from inside the cluster. Fix `spec.externalName` so it
points at a real, resolvable external DNS name.

```bash
make start    LAB=SVC-04
make validate LAB=SVC-04
make cleanup  LAB=SVC-04
make reset    LAB=SVC-04

make learn LAB=SVC-04              # concept + task + quick reference
make exam  LAB=SVC-04              # task only, no hints/solution
make hint  LAB=SVC-04 LEVEL=1
make solution LAB=SVC-04
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
