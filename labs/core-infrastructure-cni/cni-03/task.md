# CKNE-CNI-03

**Task ID:** CKNE-CNI-03
**Domain:** Core Infrastructure and CNI
**Difficulty:** Intermediate
**Estimated time:** 30 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-cni-03
**Context:** default

## Scenario

A `server` Deployment (nginx) is running and Ready in `ckne-cni-03`. A Pod named `toolbox` (image `nicolaka/netshoot`, granted `NET_ADMIN` / `NET_RAW`) is also Running and Ready — but every attempt to reach `server` on port 80 from inside `toolbox` times out.

## Objective

Using only tools available inside the `toolbox` Pod (`ip`, `iptables`), diagnose why its own outbound traffic to tcp/80 never leaves it, and fix it — entirely within `toolbox`'s own network namespace. Do not modify anything on the underlying nodes.

## Requirements

- Confirm basic routing inside `toolbox` looks sane (`kubectl exec toolbox -- ip addr`, `ip route`) — rule out an interface/routing problem before looking elsewhere.
- Inspect `toolbox`'s own iptables rules (`kubectl exec toolbox -- iptables -L -n -v --line-numbers`) and find the rule responsible for silently dropping its outbound tcp/80 traffic.
- Remove only that rule — the minimum change necessary. Do not flush all chains, and do not touch anything outside the `toolbox` Pod (no node-level iptables, no other Pod's netns).
- Confirm `toolbox` can now reach `server` on port 80.

## Verification criteria

- Deployment `server` is 1/1 Ready.
- Pod `toolbox` is Running.
- `toolbox`'s iptables `OUTPUT` chain no longer drops outbound tcp/80.
- A request from inside `toolbox` to `server`'s ClusterIP on port 80 succeeds (HTTP 200).

## Permitted references

- iptables documentation — https://www.netfilter.org/documentation/
- Debugging with network utility Pods — https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
