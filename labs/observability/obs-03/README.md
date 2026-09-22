# OBS-03 — Hubble Flows for Network Visibility

**Domain:** Observability · **Difficulty:** intermediate · **Est. time:** 25 min

A NetworkPolicy's allow/deny selector is inverted: the client that should be
blocked gets through, and the client that should be allowed doesn't. Fix the
policy, then use Hubble to directly observe both the allowed and the denied
flow at the network layer.

```bash
make start    LAB=OBS-03
make validate LAB=OBS-03
make cleanup  LAB=OBS-03
make reset    LAB=OBS-03

make learn LAB=OBS-03              # concept + task + quick reference
make exam  LAB=OBS-03              # task only, no hints/solution
make hint  LAB=OBS-03 LEVEL=1
make solution LAB=OBS-03
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
