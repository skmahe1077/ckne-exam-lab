# SEC-03 — Pod-Selector NetworkPolicy

**Domain:** Network Security and Policy · **Difficulty:** intermediate · **Est. time:** 20 min

`backend` currently accepts ingress from any Pod. Write a NetworkPolicy from
scratch that restricts ingress to only Pods carrying a specific label.

```bash
make start    LAB=SEC-03
make validate LAB=SEC-03
make cleanup  LAB=SEC-03
make reset    LAB=SEC-03

make learn LAB=SEC-03              # concept + task + quick reference
make exam  LAB=SEC-03              # task only, no hints/solution
make hint  LAB=SEC-03 LEVEL=1
make solution LAB=SEC-03
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
