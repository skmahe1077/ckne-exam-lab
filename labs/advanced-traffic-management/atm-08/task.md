# CKNE-ATM-08

**Task ID:** CKNE-ATM-08
**Domain:** Advanced Traffic Management
**Difficulty:** Advanced
**Estimated time:** 30 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-atm-08
**Context:** default

## Scenario

A `streaming-echo` backend (a stdlib-only Python server — no real LLM is involved, it only simulates one) is running in `ckne-atm-08` behind a Gateway using the cluster's shared `cilium` GatewayClass. It exposes `GET /health` (instant), `GET /stream?chunks=N&delay=S` (a chunked, incrementally-delivered response), and `GET /slow?delay=S` (sleeps `S` seconds, then responds normally). An `HTTPRoute` named `streaming-route` already routes all three paths to the backend correctly — but the `/slow` rule has no request timeout configured, so a caller hitting it can be left waiting for the backend's full delay with no bound at all.

## Objective

Add a bounded request timeout to the `/slow` rule only, so a slow backend call fails predictably instead of hanging indefinitely — without breaking `/stream`'s legitimately slow, incremental delivery.

## Requirements

- Do not modify the Gateway, the `streaming-echo` Deployment/Service, or the GatewayClass — only the HTTPRoute needs to change.
- Do not change the `/stream` or `/health` rule — they must keep running with no timeout.
- Add `timeouts.request` to the `/slow` rule only, set to a duration no shorter than 1 second and no longer than 4 seconds.
- Do not add a `retry` policy to any rule — the Gateway API CRDs installed in this cluster are the Standard release channel only, and `HTTPRoute`'s `retry` field ships in the Experimental channel, which is not installed here (see `concept.md` for why a timeout is the correct, available tool for this risk, not a retry).

## Verification criteria

- The shared GatewayClass `cilium` is Accepted (precondition, not something you are asked to change).
- Gateway `atm-08-gw` in `ckne-atm-08` reports condition `Programmed=True`.
- A real HTTP request to `/slow?delay=8` through the Gateway is cut off well before the backend's full 8-second delay — proving the configured timeout is actually enforced, not just present in the YAML.
- A real HTTP request to `/stream?chunks=5&delay=1` through the Gateway takes a duration close to the backend's real 5-second chunk schedule (not near-instant) and successfully delivers all 5 chunks — proving the response was streamed incrementally, not buffered and returned all at once, and confirming the `/stream` rule was not accidentally given a timeout that would cut it short.

## Permitted references

- Gateway API HTTPRoute timeouts — https://gateway-api.sigs.k8s.io/guides/http-timeouts/
- Gateway API HTTPRoute — https://gateway-api.sigs.k8s.io/api-types/httproute/
