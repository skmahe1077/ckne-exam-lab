# CKNE-SVC-05

**Task ID:** CKNE-SVC-05
**Domain:** Service Networking and DNS
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-05
**Context:** default

## Scenario

A `web` StatefulSet (3 replicas, nginx) is running in the `ckne-svc-05` namespace, governed by a Service also named `web` (`spec.serviceName: web`). The StatefulSet's Pods are 3/3 Ready and the Service load-balances across them fine — but per-Pod DNS names like `web-0.web.ckne-svc-05.svc.cluster.local` do not resolve to each Pod's own individual IP the way StatefulSet documentation says they should.

## Objective

Fix the `web` Service so CoreDNS creates one DNS record per StatefulSet Pod, each resolving to that specific Pod's own IP address (not a shared Service VIP).

## Requirements

- Confirm the StatefulSet `web` is 3/3 Ready (already true — the problem is not the Pods).
- Inspect the `web` Service's `spec.clusterIP`.
- Recall that `clusterIP` is immutable once a Service is created — a Service cannot be patched from a real ClusterIP to `None`. You will need to delete and recreate the Service.
- Recreate the `web` Service as a headless Service (`clusterIP: None`), keeping the same name, namespace, selector, and port so the StatefulSet's `serviceName: web` reference still resolves to it.

## Verification criteria

- StatefulSet `web` in `ckne-svc-05` has `status.readyReplicas == 3` (unchanged precondition).
- Service `web` has `spec.clusterIP == "None"`.
- For each of `web-0`, `web-1`, `web-2`: an in-cluster DNS lookup of `<pod-name>.web.ckne-svc-05.svc.cluster.local` resolves to exactly that Pod's own `status.podIP` — not a shared VIP, and not another Pod's IP.

## Permitted references

- Headless Services — https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
- StatefulSet network identity — https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#stable-network-id
