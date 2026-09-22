# ATM-04 — Gateway TLS Termination

**Domain:** Advanced Traffic Management · **Difficulty:** intermediate · **Est. time:** 30 min

A cert-manager `Certificate` is `Ready`, but the Gateway's HTTPS listener
still can't terminate TLS. Find the mismatch and fix it so a real HTTPS
request through the Gateway succeeds.

```bash
make start    LAB=ATM-04
make validate LAB=ATM-04
make cleanup  LAB=ATM-04
make reset    LAB=ATM-04

make learn LAB=ATM-04
make exam  LAB=ATM-04
make hint  LAB=ATM-04 LEVEL=1
make solution LAB=ATM-04
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
