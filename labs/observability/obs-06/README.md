# OBS-06 — End-to-End Network Troubleshooting: Latency and Packet Loss

**Domain:** Observability · **Difficulty:** advanced · **Est. time:** 35 min

A backend genuinely takes ~3s per request; a client's timeout is set to 1s.
Every request currently aborts, looking like packet loss. Use Hubble flows,
a real Prometheus latency metric, and backend's own logs together to prove
it's a timeout misconfiguration, then fix it.

```bash
make start    LAB=OBS-06
make validate LAB=OBS-06
make cleanup  LAB=OBS-06
make reset    LAB=OBS-06

make learn LAB=OBS-06              # concept + task + quick reference
make exam  LAB=OBS-06              # task only, no hints/solution
make hint  LAB=OBS-06 LEVEL=1
make solution LAB=OBS-06
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
