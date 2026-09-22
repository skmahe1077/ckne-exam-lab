# ATM-02 — Header-Based Routing

**Domain:** Advanced Traffic Management · **Difficulty:** intermediate · **Est. time:** 25 min

A `stable`/`canary` pair sits behind one Gateway. Add a header-based
HTTPRoute rule so `X-Canary: true` opts a request into the canary backend
while every other request keeps reaching stable.

```bash
make start    LAB=ATM-02
make validate LAB=ATM-02
make cleanup  LAB=ATM-02
make reset    LAB=ATM-02

make learn LAB=ATM-02              # concept + task + quick reference
make exam  LAB=ATM-02              # task only, no hints/solution
make hint  LAB=ATM-02 LEVEL=1
make solution LAB=ATM-02
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
