# Concept: ReferenceGrant for Cross-Namespace Gateway API References

Gateway API objects can reference each other across namespace boundaries in
a few places — most commonly, an `HTTPRoute`'s `backendRefs` pointing at a
`Service` that lives in a different namespace than the `HTTPRoute` itself.
Kubernetes' normal RBAC model doesn't cover this: RBAC controls who can
*create/read/modify an object*, not whether *object A in namespace X is
allowed to point at object B in namespace Y*. Without an extra guardrail, a
team that controls an `HTTPRoute` (a namespaced object) could silently
start routing traffic to — or through — a Service in someone else's
namespace, with no consent from that namespace's owner at all.

**`ReferenceGrant`** closes that gap. It is itself a namespaced object, but
critically, **it must be created in the namespace being referenced INTO**
(the target), not the namespace doing the referencing (the source). A
`ReferenceGrant` says, in effect: "I, the owner of this namespace,
explicitly consent to being referenced by objects of kind `X` from
namespace `Y`, for objects of kind `Z` in my namespace." Only once that
consent object exists does the implementation (Cilium's Gateway controller,
here) honor the cross-namespace reference; until then, the reference is
rejected and the referencing object's own status reports why
(`ResolvedRefs: False`, reason `RefNotPermitted`).

This inverts where you'd naturally look first when troubleshooting: the
`HTTPRoute` (in the *source* namespace) can be completely correct — right
Service name, right port, right namespace field — and still be rejected,
because the fix isn't there at all. It's a missing object in the *other*
namespace. This mirrors a real multi-tenant pattern: cross-namespace access
in Gateway API is consent-based and opt-in from the target's side, not
granted implicitly just because the source object's YAML is well-formed.
