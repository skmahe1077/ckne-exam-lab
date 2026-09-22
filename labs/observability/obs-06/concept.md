# Concept: End-to-End Network Troubleshooting — Latency vs. Packet Loss

A request that "just fails" can mean two very different things, and mixing
them up sends troubleshooting in the wrong direction:

- **Packet loss / a truly dropped connection**: the request or response
  never arrived at all — dropped by a NetworkPolicy, a broken route, a
  crashed process, or a genuine network fault. No amount of waiting would
  have helped; the fix is on the network/policy/process layer.
- **A client giving up too early**: the request *would have* succeeded —
  the server was still working — but the client's own timeout fired first
  and tore down the connection. To every layer downstream, this looks
  identical to a drop: the client got no response, and the connection
  closed abruptly (a TCP RST). The fix has nothing to do with the network
  at all — it's a client-side configuration value that doesn't match
  reality.

Telling these apart requires correlating **three independent signals**,
because none of them alone is conclusive:

1. **Hubble flows** show what actually happened on the wire: was a SYN/ACK
   exchanged (the connection was established — the server was reachable),
   and how did it end (a clean response, or a RST/FIN torn down early)? A
   flow that was `FORWARDED` at connection setup, but never carried a
   response before termination, points at "something gave up early" rather
   than "nothing could reach the destination".
2. **Prometheus latency metrics** give you the server's own, independently
   measured processing time — not what the client experienced, but what
   the server actually took. If that number is close to (or larger than)
   the client's configured timeout, the timeout is the likely culprit.
3. **Application logs** are the server's own account of what it did. A log
   line proving the server *did* process a specific request — just later
   than the client waited — is the clincher: it rules out "the server never
   got the request" and "the server crashed/hung", leaving only "the
   client's timeout was too tight" as the explanation.

The discipline this lab exercises: don't fix the first plausible-looking
knob (raising resource limits, adding retries, or blaming the CNI/network)
before these three signals agree on *where* the real latency lives. A
client timeout that's merely too tight for an otherwise-healthy, if slow,
backend is a very common real-world root cause that masquerades as "the
network is dropping packets" until you actually look.
