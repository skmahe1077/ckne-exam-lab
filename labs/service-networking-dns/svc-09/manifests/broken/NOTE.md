No starting scaffold is needed here — this is a build-it-yourself task, not
a fix-it task. The only objects setup.sh applies are the always-correct
`web` Deployment/Service/ConfigMap under `manifests/base/`. The `Gateway`
and `HTTPRoute` that expose `web` do not exist yet; you create both,
referencing the shared, cluster-wide `GatewayClass` named `cilium` by name
only (never create or edit a GatewayClass yourself — see task.md).
