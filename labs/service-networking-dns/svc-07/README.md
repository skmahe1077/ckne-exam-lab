# SVC-07 — kube-proxy Modes and Behaviour

**Domain:** Service Networking and DNS · **Difficulty:** intermediate · **Est. time:** 25 min

Create a Service for an existing `web` Deployment, then prove — by reading
the node's actual iptables rules through a `hostNetwork` + `NET_ADMIN`
debug Pod — that kube-proxy really did program a path from the Service's
ClusterIP to the backing Pods. This is a read-only/observational lab: no
shared cluster component is modified.

```bash
make start    LAB=SVC-07
make validate LAB=SVC-07
make cleanup  LAB=SVC-07
make reset    LAB=SVC-07

make learn LAB=SVC-07              # concept + task + quick reference
make exam  LAB=SVC-07              # task only, no hints/solution
make hint  LAB=SVC-07 LEVEL=1
make solution LAB=SVC-07
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
