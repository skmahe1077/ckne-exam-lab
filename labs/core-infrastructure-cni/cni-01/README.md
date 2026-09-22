# CNI-01 — Install and Configure Cilium CNI

**Domain:** Core Infrastructure and CNI · **Difficulty:** beginner · **Est. time:** 20 min

A `web` Deployment isn't becoming Ready. Verify whether the cluster's Cilium
CNI installation is actually at fault, then find and fix the real cause.

```bash
make start    LAB=CNI-01
make validate LAB=CNI-01
make cleanup  LAB=CNI-01
make reset    LAB=CNI-01

make learn LAB=CNI-01              # concept + task + quick reference
make exam  LAB=CNI-01              # task only, no hints/solution
make hint  LAB=CNI-01 LEVEL=1
make solution LAB=CNI-01
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
