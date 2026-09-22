# OBS-01 — Kubernetes Events and Application Logs for Network Issues

**Domain:** Observability · **Difficulty:** beginner · **Est. time:** 15 min

A `netprobe` Deployment can't reach the `backend` Service and keeps
restarting. Use Kubernetes Events and the container's own application logs
to find the real cause and fix it.

```bash
make start    LAB=OBS-01
make validate LAB=OBS-01
make cleanup  LAB=OBS-01
make reset    LAB=OBS-01

make learn LAB=OBS-01              # concept + task + quick reference
make exam  LAB=OBS-01              # task only, no hints/solution
make hint  LAB=OBS-01 LEVEL=1
make solution LAB=OBS-01
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
