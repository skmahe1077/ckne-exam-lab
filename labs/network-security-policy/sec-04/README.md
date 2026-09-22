# SEC-04 — Namespace-Selector NetworkPolicy

**Domain:** Network Security and Policy · **Difficulty:** intermediate · **Est. time:** 20 min

`backend` accepts traffic from anywhere. Restrict ingress so only Pods in
namespaces labeled `network-access: trusted` can reach it — a Pod's own
labels and its physical namespace proximity to `backend` don't matter.

```bash
make start    LAB=SEC-04
make validate LAB=SEC-04
make cleanup  LAB=SEC-04
make reset    LAB=SEC-04

make learn LAB=SEC-04
make exam  LAB=SEC-04
make hint  LAB=SEC-04 LEVEL=1
make solution LAB=SEC-04
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
