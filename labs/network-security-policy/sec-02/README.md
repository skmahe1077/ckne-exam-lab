# SEC-02 — Default-Deny Egress NetworkPolicy

**Domain:** Network Security and Policy · **Difficulty:** beginner · **Est. time:** 25 min

A default-deny-egress NetworkPolicy blocks all outbound traffic from
`client`, including DNS. Add scoped egress-allow rules for CoreDNS and one
specific target Service, while a second target stays unreachable.

```bash
make start    LAB=SEC-02
make validate LAB=SEC-02
make cleanup  LAB=SEC-02
make reset    LAB=SEC-02

make learn LAB=SEC-02              # concept + task + quick reference
make exam  LAB=SEC-02              # task only, no hints/solution
make hint  LAB=SEC-02 LEVEL=1
make solution LAB=SEC-02
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
