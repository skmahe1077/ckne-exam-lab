# OBS-04 — Prometheus Metrics for Network Components

**Domain:** Observability · **Difficulty:** advanced · **Est. time:** 30 min

A small app's Service is annotated for Prometheus auto-discovery, but the
scrape port is wrong, so its metric never appears. Fix the annotation,
generate real traffic, and prove metrics are flowing with real PromQL
queries against the cluster's shared Prometheus server.

```bash
make start    LAB=OBS-04
make validate LAB=OBS-04
make cleanup  LAB=OBS-04
make reset    LAB=OBS-04

make learn LAB=OBS-04              # concept + task + quick reference
make exam  LAB=OBS-04              # task only, no hints/solution
make hint  LAB=OBS-04 LEVEL=1
make solution LAB=OBS-04
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
