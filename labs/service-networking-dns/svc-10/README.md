# SVC-10 — Gateway API ReferenceGrant Across Namespaces

**Domain:** Service Networking and DNS · **Difficulty:** intermediate · **Est. time:** 20 min

An `HTTPRoute` in `ckne-svc-10` correctly references a `backend` Service in
`ckne-svc-10-backend`, but the reference is rejected — no `ReferenceGrant`
exists in the target namespace yet. Create it, and prove the cross-namespace
route works end-to-end.

```bash
make start    LAB=SVC-10
make validate LAB=SVC-10
make cleanup  LAB=SVC-10
make reset    LAB=SVC-10

make learn LAB=SVC-10              # concept + task + quick reference
make exam  LAB=SVC-10              # task only, no hints/solution
make hint  LAB=SVC-10 LEVEL=1
make solution LAB=SVC-10
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
