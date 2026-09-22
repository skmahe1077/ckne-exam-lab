# CNI-05 — DNS Troubleshooting at Node and Pod Level

**Domain:** Core Infrastructure and CNI · **Difficulty:** intermediate · **Est. time:** 25 min

A `client` Pod can't resolve any in-cluster DNS names, including a healthy
`server` Service in the same namespace. Determine whether CoreDNS itself is
broken cluster-wide or the problem is specific to `client`, then fix it.

```bash
make start    LAB=CNI-05
make validate LAB=CNI-05
make cleanup  LAB=CNI-05
make reset    LAB=CNI-05

make learn LAB=CNI-05
make exam  LAB=CNI-05
make hint  LAB=CNI-05 LEVEL=1
make solution LAB=CNI-05
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
