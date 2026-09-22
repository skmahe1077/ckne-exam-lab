# ATM-07 — Cross-Cluster Load Balancing

**Domain:** Advanced Traffic Management · **Difficulty:** advanced · **Est. time:** 35 min

**Scope note:** this environment has only one real Kubernetes cluster. This
lab is a configuration and control-plane readiness exercise for Cilium
Cluster Mesh's cross-cluster load-balancing affinity — you confirm the
`clustermesh-apiserver` control plane is healthy, then correctly configure a
Service's load-balancing preference. It does **not** test real traffic being
distributed between two clusters — see `concept.md` and `task.md` for the
full scope limitation.

```bash
make start    LAB=ATM-07
make validate LAB=ATM-07
make cleanup  LAB=ATM-07
make reset    LAB=ATM-07

make learn LAB=ATM-07              # concept + task + quick reference
make exam  LAB=ATM-07              # task only, no hints/solution
make hint  LAB=ATM-07 LEVEL=1
make solution LAB=ATM-07
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
