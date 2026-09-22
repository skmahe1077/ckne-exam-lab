# SEC-06 — IPBlock NetworkPolicy

**Domain:** Network Security and Policy · **Difficulty:** intermediate · **Est. time:** 25 min

Two probe Pods, `client-a` and `client-b`, sit on different worker nodes. A
`NetworkPolicy` currently allows both of them to reach `backend`. Fix its
`ipBlock`/`except` rule so only `client-a`'s node's Pod CIDR sub-range is
allowed.

```bash
make start    LAB=SEC-06
make validate LAB=SEC-06
make cleanup  LAB=SEC-06
make reset    LAB=SEC-06

make learn LAB=SEC-06              # concept + task + quick reference
make exam  LAB=SEC-06              # task only, no hints/solution
make hint  LAB=SEC-06 LEVEL=1
make solution LAB=SEC-06
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
