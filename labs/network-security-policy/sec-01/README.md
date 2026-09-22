# SEC-01 — Default-Deny Ingress NetworkPolicy

**Domain:** Network Security and Policy · **Difficulty:** beginner · **Est. time:** 20 min

A default-deny-ingress NetworkPolicy blocks all traffic to `backend`,
including a legitimate client. Add a scoped ingress-allow rule so only
Pods labeled `role: frontend` can reach it, while everything else stays
denied.

```bash
make start    LAB=SEC-01
make validate LAB=SEC-01
make cleanup  LAB=SEC-01
make reset    LAB=SEC-01

make learn LAB=SEC-01              # concept + task + quick reference
make exam  LAB=SEC-01              # task only, no hints/solution
make hint  LAB=SEC-01 LEVEL=1
make solution LAB=SEC-01
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
