# OBS-05 — Envoy Access Logs and Jaeger Distributed Tracing

**Domain:** Observability · **Difficulty:** advanced · **Est. time:** 35 min

A Telemetry object's access-log provider name is typo'd, and a trace
reporter's Jaeger collector port is wrong. Fix both, then prove — with a
real request and a real submitted-and-queried span — that Envoy access logs
and Jaeger tracing are actually flowing.

```bash
make start    LAB=OBS-05
make validate LAB=OBS-05
make cleanup  LAB=OBS-05
make reset    LAB=OBS-05

make learn LAB=OBS-05              # concept + task + quick reference
make exam  LAB=OBS-05              # task only, no hints/solution
make hint  LAB=OBS-05 LEVEL=1
make solution LAB=OBS-05
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
