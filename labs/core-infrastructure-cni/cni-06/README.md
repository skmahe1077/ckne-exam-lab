# CNI-06 — Multi-Interface Pods

**Domain:** Core Infrastructure and CNI · **Difficulty:** advanced · **Est. time:** 35 min

This cluster has no Multus CNI meta-plugin installed, so real secondary-NIC
attachment isn't available here. Instead, simulate the *design pattern*
multi-interface Pods exist for — isolating traffic planes with independent
security boundaries — using a two-container Pod (`data-plane` +
`mgmt-plane`, one port each) and a per-port `NetworkPolicy`. Read
`concept.md` first: it is explicit about exactly what is and isn't being
simulated.

```bash
make start    LAB=CNI-06
make validate LAB=CNI-06
make cleanup  LAB=CNI-06
make reset    LAB=CNI-06

make learn LAB=CNI-06              # concept + task + quick reference
make exam  LAB=CNI-06              # task only, no hints/solution
make hint  LAB=CNI-06 LEVEL=1
make solution LAB=CNI-06
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
