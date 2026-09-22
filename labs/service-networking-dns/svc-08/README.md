# SVC-08 — CoreDNS Configuration and Forwarding

**Domain:** Service Networking and DNS · **Difficulty:** advanced · **Est. time:** 35 min

The shared cluster CoreDNS Corefile has a misconfigured scoped `forward`
block for a fictional test zone. Fix only that block so it correctly
forwards to a self-hosted resolver in your namespace, without breaking
normal in-cluster DNS for anyone else. This lab modifies the shared
`kube-system/coredns` ConfigMap under a lock — setup backs up the original
content and cleanup restores it exactly.

```bash
make start    LAB=SVC-08
make validate LAB=SVC-08
make cleanup  LAB=SVC-08
make reset    LAB=SVC-08

make learn LAB=SVC-08              # concept + task + quick reference
make exam  LAB=SVC-08              # task only, no hints/solution
make hint  LAB=SVC-08 LEVEL=1
make solution LAB=SVC-08
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
