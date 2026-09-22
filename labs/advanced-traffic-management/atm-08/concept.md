# Concept: Timeouts and Retry Risk Against Slow, Streaming Backends

LLM-serving traffic breaks two assumptions most HTTP routing config quietly
makes: that a response arrives quickly, and that it arrives all at once.
Token-by-token generation means a healthy response can legitimately take many
seconds and arrive as a sequence of chunks rather than a single payload —
which means the *default* timeout and buffering behavior tuned for typical
CRUD APIs is actively wrong for this kind of backend, in both directions.

This lab uses a small stdlib-only Python server (`shared/manifests/
streaming-echo/deployment.yaml` — no real model involved) to stand in for
that behavior safely: `/slow?delay=S` sleeps `S` seconds then returns a
normal response (simulating a slow-but-not-broken completion), and
`/stream?chunks=N&delay=S` writes `N` chunks, one every `S` seconds, using
HTTP chunked transfer encoding (simulating token streaming).

**Why an unbounded `/slow` is dangerous — the retry risk.** Gateway API's
`HTTPRoute` `rules[].timeouts.request` field (Standard channel, `Support:
Extended`) bounds how long the Gateway will wait for a backend to respond
before giving up and returning an error to the client. Leave it unset, and a
slow backend call can hang for its full duration with no limit. The failure
mode this invites isn't the hang itself — it's what happens next: a caller
(or a well-meaning retry wrapper) that gives up waiting and immediately
retries doesn't cancel the first request; the original backend call is often
still running. A second full-price request now lands on a backend that's
already mid-flight on the first one, and if that pattern repeats under load,
each retry compounds the very slowness that triggered it. This is why a
*bounded* timeout on the risky path is the safer default, even without
configuring retries at all — it turns an unbounded wait into a fast,
predictable failure the caller can reason about.

This cluster's Gateway API CRDs are installed from the **Standard** release
channel only (`kubeadm-setup/install-addons.sh` applies
`standard-install.yaml`). `timeouts` is part of that channel. `HTTPRoute`'s
`retry` field, by contrast, is annotated `<gateway:experimental>` upstream
and ships only in the **Experimental** channel — it is not present in this
cluster's CRDs at all. That's a deliberate reason this lab configures a
timeout rather than a retry policy: the safer, available primitive is the
timeout itself, not adding automatic retries on top of a slow backend.

**Why `/stream` must NOT get the same timeout.** `rules[].timeouts.request`
applies to the whole route, and a streamed response can legitimately take as
long as the model takes to finish generating — cutting it off with a short
timeout would kill a perfectly healthy, in-progress stream. The signal that
distinguishes a genuinely streamed response from a buffered one isn't the
final content — a buffering proxy can still eventually deliver the full
body — it's *when* the bytes arrive. A request whose total duration tracks
the backend's `chunks × delay` schedule was delivered incrementally; a
request that returns near-instantly despite a multi-second chunk schedule
was buffered somewhere in the path before being flushed to the client.
