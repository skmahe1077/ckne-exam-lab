# ATM-08 — Simulated LLM Traffic: Streaming, Timeouts, Retry Risks

**Domain:** Advanced Traffic Management · **Difficulty:** advanced · **Est. time:** 30 min

A stdlib-only Python backend (`streaming-echo` — no real LLM involved)
simulates a slow, chunked-response upstream: `/slow` sleeps before replying,
`/stream` sends several chunks over several seconds. An `HTTPRoute` behind
the shared `cilium` Gateway routes to it correctly, but `/slow` has no
request timeout — leaving callers exposed to unbounded waits and the naive
"just retry on timeout" instinct that quietly doubles load on an
already-struggling backend. Add a bounded timeout to `/slow` only, without
breaking `/stream`'s legitimately slow, incremental delivery.

```bash
make start    LAB=ATM-08
make validate LAB=ATM-08
make cleanup  LAB=ATM-08
make reset    LAB=ATM-08

make learn LAB=ATM-08              # concept + task + quick reference
make exam  LAB=ATM-08              # task only, no hints/solution
make hint  LAB=ATM-08 LEVEL=1
make solution LAB=ATM-08
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
