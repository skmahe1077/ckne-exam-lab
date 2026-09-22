# CKNE-SVC-06

**Task ID:** CKNE-SVC-06
**Domain:** Service Networking and DNS
**Difficulty:** Intermediate
**Estimated time:** 20 minutes
**Weight:** 2.5%
**Cluster:** ckne-hands-on
**Namespace:** ckne-svc-06
**Context:** default

## Scenario

A `web` Deployment (2 replicas, nginx) and its `web` Service were deployed into `ckne-svc-06`, but the Service delivers no traffic. Both Pods show `Running` with `0/2` Ready.

## Objective

Get both `web` Pods to `Ready`, confirm the `web` Service's EndpointSlice reflects them as usable endpoints, and confirm the Service routes traffic end-to-end again.

## Requirements

- Inspect the Pods' readiness status and probe output (`kubectl describe pod`, `kubectl get events`) to find out why they are not becoming Ready.
- Fix the readinessProbe configuration with the minimum change necessary — do not remove the probe, do not change the container image, do not modify the Service.
- Confirm the Deployment reaches `2/2` Ready.
- Inspect the actual EndpointSlice object(s) for the Service (`kubectl get endpointslice -n ckne-svc-06 -l kubernetes.io/service-name=web -o yaml`) and confirm both Pod addresses are listed with `conditions.ready: true`.
- Confirm the Service actually delivers traffic to the Pods.

## Verification criteria

- Deployment `web` in `ckne-svc-06` has `status.readyReplicas == 2`.
- The EndpointSlice(s) selecting Service `web` list exactly 2 endpoint addresses, all with `conditions.ready == true`.
- A request to the `web` Service (`web.ckne-svc-06.svc.cluster.local`, port 80) succeeds end-to-end from another Pod in the cluster.

## Permitted references

- Kubernetes EndpointSlices — https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Configure liveness/readiness probes — https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
