# OBS-02 — CoreDNS Logs, Service and Endpoint Health

**Domain:** Observability · **Difficulty:** intermediate · **Est. time:** 20 min

The `orders` Service can't reach its Pods. Read CoreDNS's own logs to rule
DNS in or out, then correctly diagnose the real Service/Endpoint health
problem and fix it.

```bash
make start    LAB=OBS-02
make validate LAB=OBS-02
make cleanup  LAB=OBS-02
make reset    LAB=OBS-02

make learn LAB=OBS-02              # concept + task + quick reference
make exam  LAB=OBS-02              # task only, no hints/solution
make hint  LAB=OBS-02 LEVEL=1
make solution LAB=OBS-02
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
