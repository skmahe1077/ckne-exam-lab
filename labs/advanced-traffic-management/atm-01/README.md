# ATM-01 — Host- and Path-Based HTTPRoute Routing

**Domain:** Advanced Traffic Management · **Difficulty:** beginner · **Est. time:** 20 min

Two backends, `blue` and `green`, sit behind one Gateway. Their HTTPRoute
objects have swapped backendRefs — fix host-based and path-based routing so
each hostname/path reaches the correct backend.

```bash
make start    LAB=ATM-01
make validate LAB=ATM-01
make cleanup  LAB=ATM-01
make reset    LAB=ATM-01

make learn LAB=ATM-01              # concept + task + quick reference
make exam  LAB=ATM-01              # task only, no hints/solution
make hint  LAB=ATM-01 LEVEL=1
make solution LAB=ATM-01
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
