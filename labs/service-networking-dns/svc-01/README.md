# SVC-01 — ClusterIP Services and Selectors

**Domain:** Service Networking and DNS · **Difficulty:** beginner · **Est. time:** 15 min

An `api` Service exists alongside a healthy `api` Deployment, but no traffic
reaches the Pods. Find and fix the Service so it actually routes.

```bash
make start    LAB=SVC-01
make validate LAB=SVC-01
make cleanup  LAB=SVC-01
make reset    LAB=SVC-01

make learn LAB=SVC-01              # concept + task + quick reference
make exam  LAB=SVC-01              # task only, no hints/solution
make hint  LAB=SVC-01 LEVEL=1
make solution LAB=SVC-01
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
