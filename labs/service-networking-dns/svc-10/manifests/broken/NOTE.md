No starting scaffold is needed here beyond the always-correct objects under
`manifests/base/` (Gateway + HTTPRoute in the primary namespace, backend
Deployment/Service in the second namespace). This is a build-it-yourself
task: the `ReferenceGrant` that must exist in the backend namespace before
the HTTPRoute's cross-namespace `backendRef` is honored does not exist yet
— you create it. See `task.md` and `manifests/expected/referencegrant.yaml`.
