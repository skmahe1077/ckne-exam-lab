# SEC-08 — Cilium L3/L4/L7 Network Policy and Transparent Encryption

**Domain:** Network Security and Policy · **Difficulty:** advanced · **Est. time:** 40 min

Two independent sub-tasks. Part A: write a `CiliumNetworkPolicy` that
combines L3/L4 identity-based filtering with L7 HTTP-aware filtering — only
`GET /health` from the `caller` Pod may reach `backend`; everything else
(including `POST /admin` from that same Pod, and any request at all from
`outsider`) must be blocked, something a plain `NetworkPolicy` cannot
express. Part B: enable Cilium's WireGuard transparent encryption
cluster-wide via a locked Helm value change, and confirm it is really
active.

```bash
make start    LAB=SEC-08
make validate LAB=SEC-08
make cleanup  LAB=SEC-08
make reset    LAB=SEC-08

make learn LAB=SEC-08
make exam  LAB=SEC-08
make hint  LAB=SEC-08 LEVEL=1
make solution LAB=SEC-08
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
