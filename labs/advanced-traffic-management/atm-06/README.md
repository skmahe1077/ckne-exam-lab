# ATM-06 — Cross-Cluster Service Discovery

**Domain:** Advanced Traffic Management · **Difficulty:** advanced · **Est. time:** 35 min

**Scope note:** this environment has only one real Kubernetes cluster. This
lab is a configuration and control-plane readiness exercise for Cilium
Cluster Mesh — you deploy and inspect the `clustermesh-apiserver` control
plane and its mTLS certificates, and correctly mark a Service for
cross-cluster discovery. It does **not** test real traffic failing over
between two clusters — see `concept.md` and `task.md` for the full scope
limitation.

```bash
make start    LAB=ATM-06
make validate LAB=ATM-06
make cleanup  LAB=ATM-06
make reset    LAB=ATM-06

make learn LAB=ATM-06              # concept + task + quick reference
make exam  LAB=ATM-06              # task only, no hints/solution
make hint  LAB=ATM-06 LEVEL=1
make solution LAB=ATM-06
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
