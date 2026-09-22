# CNI-03 — Linux Routing and iptables for Pod Traffic

**Domain:** Core Infrastructure and CNI · **Difficulty:** intermediate · **Est. time:** 30 min

A NET_ADMIN-capable `toolbox` Pod can't reach the `server` Deployment on
port 80. Use `ip` and `iptables` inside `toolbox`'s own network namespace to
find and remove the rule that's silently dropping its outbound traffic.

```bash
make start    LAB=CNI-03
make validate LAB=CNI-03
make cleanup  LAB=CNI-03
make reset    LAB=CNI-03

make learn LAB=CNI-03              # concept + task + quick reference
make exam  LAB=CNI-03              # task only, no hints/solution
make hint  LAB=CNI-03 LEVEL=1
make solution LAB=CNI-03
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
