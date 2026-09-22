# SEC-07 — DNS Egress Control

**Domain:** Network Security and Policy · **Difficulty:** intermediate · **Est. time:** 20 min

A `deny-all-egress` policy blocks DNS along with everything else. Without
touching that policy, add exactly the egress needed for DNS to work again —
nothing more.

```bash
make start    LAB=SEC-07
make validate LAB=SEC-07
make cleanup  LAB=SEC-07
make reset    LAB=SEC-07

make learn LAB=SEC-07
make exam  LAB=SEC-07
make hint  LAB=SEC-07 LEVEL=1
make solution LAB=SEC-07
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
