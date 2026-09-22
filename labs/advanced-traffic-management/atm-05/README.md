# ATM-05 — Egress Gateway Traffic Control

**Domain:** Advanced Traffic Management · **Difficulty:** intermediate · **Est. time:** 30 min

Cilium's egress gateway feature has been enabled cluster-wide and a dedicated
gateway node has been labeled, but the `CiliumEgressGatewayPolicy` that is
supposed to route `egress-client`'s traffic through that node doesn't
actually select any Pods. Fix the policy's selector so egress traffic is
correctly redirected and SNATed through the designated gateway node.

```bash
make start    LAB=ATM-05
make validate LAB=ATM-05
make cleanup  LAB=ATM-05
make reset    LAB=ATM-05

make learn LAB=ATM-05              # concept + task + quick reference
make exam  LAB=ATM-05              # task only, no hints/solution
make hint  LAB=ATM-05 LEVEL=1
make solution LAB=ATM-05
```

See `task.md` for the full task spec, `concept.md` for background, and
`quick-reference.md` for exam-permitted documentation links.
