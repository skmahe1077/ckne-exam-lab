# Hints — ATM-01

## Level 1

Look at what's actually deployed before touching anything:

```bash
kubectl -n ckne-atm-01 get gateway atm-gw
kubectl -n ckne-atm-01 get httproute
kubectl -n ckne-atm-01 get svc
```

Confirm the `blue` and `green` Services and Deployments are healthy first —
they are not the problem. The task is entirely inside the HTTPRoute objects.

## Level 2

Read the full spec of each HTTPRoute, not just its name:

```bash
kubectl -n ckne-atm-01 get httproute host-routes -o yaml
kubectl -n ckne-atm-01 get httproute host-routes-green -o yaml
kubectl -n ckne-atm-01 get httproute path-routes -o yaml
```

For each one, compare the HTTPRoute's own name/hostname against the
`backendRefs.name` it points to, and (for `path-routes`) compare each
rule's `matches[].path.value` against its `backendRefs.name`.

## Level 3

Every `host-routes*` object routes a hostname to the *wrong-named*
`backendRefs`, and `path-routes` routes each path prefix to the
*wrong-named* `backendRefs`. Edit each HTTPRoute (`kubectl edit httproute
<name> -n ckne-atm-01`) so hostname/path and `backendRefs.name` line up:
`blue.ckne.local` → `blue`, `green.ckne.local` → `green`, `/blue` → `blue`,
`/green` → `green`. Nothing about the Gateway or backend Services needs to
change.
