# CKNE-CNI-04

**Task ID:** CKNE-CNI-04
**Domain:** Core Infrastructure and CNI
**Difficulty:** Intermediate
**Estimated time:** 30 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-cni-04
**Context:** default

## Scenario

A `client` Deployment and a `server` Pod (containers `web` running nginx, and `debug`, a `nicolaka/netshoot` sidecar sharing `web`'s network namespace) are both Running and Ready in `ckne-cni-04`. A ClusterIP Service named `server` is supposed to expose `web` on port 80, but requests from `client` to the Service never get a response.

## Objective

Using `ss` and `tcpdump` to inspect what's actually happening on the wire (not just object state), determine why traffic through the Service never reaches nginx, and fix it with the minimum change necessary.

## Requirements

- From inside the `debug` container (same netns as `web`), use `ss` to list the sockets `web` actually has listening (`kubectl -n ckne-cni-04 exec server -c debug -- ss -tlnp`).
- While attempting a connection from `client` to the `server` Service, capture traffic on `debug`'s `eth0` with `tcpdump` to observe what actually arrives at the Pod and how the kernel responds to it.
- Compare what you captured against the Service's configuration (`kubectl -n ckne-cni-04 get svc server -o yaml`) to find the mismatch.
- Fix the mismatch with the minimum change necessary — do not change the client's request target, and do not add a second container port to work around the bug.
- Confirm `client` can now reach `server` via the Service on port 80.

## Verification criteria

- Deployment `client` is 1/1 Ready.
- Pod `server` has both containers (`web`, `debug`) Ready.
- Service `server` exists.
- A request from `client` to `server`'s Service DNS name on port 80 returns HTTP 200.

## Permitted references

- Kubernetes Services — https://kubernetes.io/docs/concepts/services-networking/service/
- Debugging Services — https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
