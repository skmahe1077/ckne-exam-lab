# Command Reference (learning-mode only — not shown in exam mode)

A cheat-sheet of the commands used repeatedly across labs. This file is
intentionally NOT linked from any lab's `quick-reference.md` and is not
shown by `make exam` — it's for practicing outside exam conditions, similar
in spirit to `make learn`.

## Cluster / node state

```bash
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

## Services, Endpoints, DNS

```bash
kubectl get svc,endpoints,endpointslice -n <ns>
kubectl -n <ns> run dnsutils --image=busybox:1.36 --restart=Never --rm -it -- nslookup <name>.<ns>.svc.cluster.local
kubectl -n kube-system get configmap coredns -o yaml
kubectl -n kube-system logs -l k8s-app=kube-dns
```

## Cilium / Hubble

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system exec ds/cilium -- cilium status
kubectl -n kube-system exec ds/cilium -- cilium endpoint list
kubectl -n kube-system exec deploy/hubble-relay -- hubble observe --namespace <ns>
```

## Gateway API

```bash
kubectl get gatewayclass
kubectl get gateway,httproute -n <ns>
kubectl describe httproute <name> -n <ns>
```

## NetworkPolicy / CiliumNetworkPolicy

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy <name> -n <ns>
kubectl get ciliumnetworkpolicy -n <ns>
```

## Istio

```bash
kubectl get pods -n <ns> -o jsonpath='{.items[*].spec.containers[*].name}'   # look for istio-proxy
kubectl get peerauthentication,authorizationpolicy -n <ns>
kubectl -n <ns> logs <pod> -c istio-proxy
```

## Observability

```bash
kubectl -n monitoring port-forward svc/prometheus-server 9090:80
kubectl -n observability get pods -l app.kubernetes.io/name=jaeger
```

## Debug pod (netshoot — has ip, ss, tcpdump, curl, dig, nc, iptables)

```bash
kubectl -n <ns> run debug --image=nicolaka/netshoot --restart=Never -it --rm -- bash
```

## This repository's own tooling

```bash
make aws-status
make cluster-verify
make start LAB=<id>
make validate LAB=<id>
make cleanup LAB=<id>
make active-labs
```
