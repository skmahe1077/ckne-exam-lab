# Concept: ipBlock NetworkPolicy Rules

`NetworkPolicy` `from`/`to` peers can select traffic three ways: `podSelector`
(by Pod labels), `namespaceSelector` (by namespace labels), or `ipBlock` (by
raw CIDR). `ipBlock` is the odd one out — it matches on IP address, not on
any Kubernetes object, so it is the only peer type usable for things that
aren't Pods at all (an external partner network, a specific subnet on your
VPC, or — as in this lab — a specific node's slice of the cluster's Pod
CIDR).

An `ipBlock` entry looks like:

```yaml
ipBlock:
  cidr: 10.244.0.0/16
  except:
    - 10.244.2.0/24
```

`except` must be a subset of `cidr`. It carves a hole out of an otherwise
allowed range — the effective allowed set is "everything in `cidr` that is
not in any `except` entry." This is different from writing two `ipBlock`
entries with disjoint CIDRs: `except` only makes sense when you want to
allow a broad range *and* explicitly deny a narrower range nested inside it.

**Why Pod-to-Pod ipBlock rules need care:** in most CNIs (Cilium included,
running the default kubeadm allocate-node-cidrs setup used by this cluster),
each node is handed a stable sub-range of the cluster Pod CIDR
(`10.244.0.0/16`), and every Pod scheduled on that node gets an IP from that
node's sub-range. Individual Pod IPs are ephemeral (they change every time a
Pod is rescheduled), but the node-to-subrange assignment is stable for the
node's lifetime. That is what makes an `ipBlock`+`except` rule keyed on a
node's sub-range meaningful and durable in a way that hardcoding a specific
Pod IP would not be.

`ipBlock` rules are evaluated purely on source/destination IP — they do not
care about Pod labels or identity, so an `ipBlock` rule and a `podSelector`
rule inside the same `NetworkPolicy` behave as alternatives ("allowed if
EITHER peer type matches"), never as an AND condition.
