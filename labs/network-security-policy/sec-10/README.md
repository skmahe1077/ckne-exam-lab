# SEC-10 — Istio mTLS and AuthorizationPolicy

**Domain:** Network Security and Policy · **Difficulty:** advanced · **Est. time:** 40 min

`ckne-sec-10` is Istio sidecar-injected. `backend` currently accepts
plaintext and any caller identity. Add a namespace-scoped `PeerAuthentication`
(mode `STRICT`) so only mTLS connections are accepted, and an
`AuthorizationPolicy` so only the `trusted-caller-sa` ServiceAccount
identity may actually call `backend` — a second, mesh-authenticated but
unauthorized caller, and a third, sidecar-less plaintext caller, must both
be rejected.

```bash
make start    LAB=SEC-10
make validate LAB=SEC-10
make cleanup  LAB=SEC-10
make reset    LAB=SEC-10

make learn LAB=SEC-10
make exam  LAB=SEC-10
make hint  LAB=SEC-10 LEVEL=1
make solution LAB=SEC-10
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
