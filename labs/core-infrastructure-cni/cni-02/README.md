# CNI-02 — Pod CIDR and IPAM Allocation

**Domain:** Core Infrastructure and CNI · **Difficulty:** beginner · **Est. time:** 20 min

A `client` Deployment can't reach a `server` Deployment even though both are
Ready. A NetworkPolicy is supposed to allow the traffic — confirm the
cluster's real Pod CIDR from actual running Pods, then fix the policy so it
matches.

```bash
make start    LAB=CNI-02
make validate LAB=CNI-02
make cleanup  LAB=CNI-02
make reset    LAB=CNI-02

make learn LAB=CNI-02              # concept + task + quick reference
make exam  LAB=CNI-02              # task only, no hints/solution
make hint  LAB=CNI-02 LEVEL=1
make solution LAB=CNI-02
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
