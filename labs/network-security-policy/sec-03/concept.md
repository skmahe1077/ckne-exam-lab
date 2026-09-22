# Concept: Pod-Selector Scoped NetworkPolicy

A `NetworkPolicy`'s `spec.podSelector` chooses which Pods the policy applies
to (in this lab, `app: backend`). Its `ingress[].from[].podSelector` chooses
which OTHER Pods are allowed to originate traffic — matched by label, not by
name or IP. Because `podSelector` (with no accompanying `namespaceSelector`)
implicitly means "Pods matching this label, in the same namespace as the
policy," this is the narrowest possible way to say "only clients carrying
this specific label may talk to this backend" without hardcoding IPs, which
change every time a Pod is rescheduled.

There is no separate "default-deny" object to create here: the moment ANY
NetworkPolicy with `policyTypes: [Ingress]` selects a Pod, Kubernetes
implicitly switches that Pod from "allow all ingress" to "deny all ingress
except what's explicitly listed." Writing a single policy with a
`role: frontend` `podSelector` rule therefore does two things at once — it
implicitly denies every other Pod, and it explicitly allows exactly the one
label you specified. This differs from SEC-01, where the deny and the allow
were two separate, already-existing/to-be-added policies — here you build
both effects with one object.
