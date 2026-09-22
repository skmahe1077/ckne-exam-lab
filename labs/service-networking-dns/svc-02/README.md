# SVC-02 — NodePort Services

**Domain:** Service Networking and DNS · **Difficulty:** beginner · **Est. time:** 15 min

A `web` NodePort Service has a valid nodePort and healthy Endpoints, but
traffic sent to `<node-IP>:<nodePort>` never reaches a Pod. Find and fix
it.

```bash
make start    LAB=SVC-02
make validate LAB=SVC-02
make cleanup  LAB=SVC-02
make reset    LAB=SVC-02

make learn LAB=SVC-02              # concept + task + quick reference
make exam  LAB=SVC-02              # task only, no hints/solution
make hint  LAB=SVC-02 LEVEL=1
make solution LAB=SVC-02
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
