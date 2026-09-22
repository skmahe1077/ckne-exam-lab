# ATM-03 — Weighted Traffic Splitting (Canary)

**Domain:** Advanced Traffic Management · **Difficulty:** intermediate · **Est. time:** 25 min

A `stable`/`canary` pair is split 50/50 by an HTTPRoute's `backendRefs`
weights. Change the weights to an 80/20 split and prove it with real
sampled traffic (within a generous statistical tolerance — see task.md).

```bash
make start    LAB=ATM-03
make validate LAB=ATM-03
make cleanup  LAB=ATM-03
make reset    LAB=ATM-03

make learn LAB=ATM-03              # concept + task + quick reference
make exam  LAB=ATM-03              # task only, no hints/solution
make hint  LAB=ATM-03 LEVEL=1
make solution LAB=ATM-03
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
