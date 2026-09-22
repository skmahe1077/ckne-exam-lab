# Backend source

This lab's backend (the `streaming-echo` ConfigMap/Deployment/Service — a
stdlib-only Python server simulating a slow, chunked/streaming LLM-style
upstream with `/health`, `/stream`, and `/slow` endpoints) is **not**
duplicated into this directory. `setup.sh` applies it directly from
`shared/manifests/streaming-echo/deployment.yaml`, sed-substituting
`${NAMESPACE}`/`${TASK_ID}` the same way it does for every manifest under
this lab's own `manifests/` directory, so this always-correct object is
applied unconditionally alongside `manifests/base/gateway.yaml`.

See `shared/manifests/streaming-echo/deployment.yaml` for the endpoint
contract (`GET /health`, `GET /stream?chunks=N&delay=S`,
`GET /slow?delay=S`).
