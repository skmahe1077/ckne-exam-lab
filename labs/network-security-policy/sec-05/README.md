# SEC-05 — Combined Pod and Namespace Selectors

**Domain:** Network Security and Policy · **Difficulty:** intermediate · **Est. time:** 25 min

`backend` must accept ingress only from Pods that are **both** in the
trusted `ckne-sec-05-clients` namespace **and** carry the `role: frontend`
label — one condition alone is not enough. Getting the `NetworkPolicy`'s
`from` list wrong (two separate entries instead of one combined entry)
silently turns this AND into an OR, and `validate.sh` will catch it.

```bash
make start    LAB=SEC-05
make validate LAB=SEC-05
make cleanup  LAB=SEC-05
make reset    LAB=SEC-05

make learn LAB=SEC-05
make exam  LAB=SEC-05
make hint  LAB=SEC-05 LEVEL=1
make solution LAB=SEC-05
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
