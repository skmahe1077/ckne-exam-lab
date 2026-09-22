# CNI-04 — Diagnosing Pod-to-Pod Connectivity

**Domain:** Core Infrastructure and CNI · **Difficulty:** intermediate · **Est. time:** 30 min

A `client` Pod can't reach a `server` Pod through its Service even though
both are Ready. Use `ss` and `tcpdump` from a debug sidecar sharing the
server's network namespace to find the real cause on the wire, then fix it.

```bash
make start    LAB=CNI-04
make validate LAB=CNI-04
make cleanup  LAB=CNI-04
make reset    LAB=CNI-04

make learn LAB=CNI-04              # concept + task + quick reference
make exam  LAB=CNI-04              # task only, no hints/solution
make hint  LAB=CNI-04 LEVEL=1
make solution LAB=CNI-04
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
