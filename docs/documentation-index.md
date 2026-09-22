# Documentation Index — Exam-Permitted Sources

Every lab's `quick-reference.md` draws only from this allow-list. It
mirrors the official CKNE exam policy ("Certified Kubernetes Network
Engineer (CKNE) — allowed tools and resources"), reproduced below for
reference. No community blogs, Medium, Reddit, Stack Overflow,
search-engine results, AI-generated research, or training-provider
solution write-ups anywhere in this repository's lab content.

## Official policy (as published by the exam provider)

During the exam, candidates may:

- Use the browser to access **Kubernetes Documentation**
  (https://kubernetes.io/docs) — using the site's own search function is
  allowed, but opening external search-engine results is not.
- Use the browser to access the **Kubernetes Blog**
  (https://kubernetes.io/blog/).
- Use **task-specific documentation provided in the Quick Reference box**
  for each task — this includes links to documentation for the specific
  tools a task needs (see "Tool-specific" below for the tools this
  repository's labs draw on).
- Use **any available language translation** of kubernetes.io/docs (e.g.
  https://kubernetes.io/zh/docs/) — English is recommended in practice
  since localized translations can lag the latest release, but this
  repository's `quick-reference.md` files always link the English version
  for consistency.
- Review whatever **exam content instructions are presented in the
  terminal** for the task at hand — in this repository, that's each lab's
  `task.md` in exam mode (`make exam LAB=...`).
- Review **documents installed by the Linux distribution** (i.e.
  `/usr/share` and its subdirectories — man pages, package docs, etc.) on
  the machine the task is being worked from.
- Use **packages that are part of the distribution** (or installed by the
  candidate if not already present).

This repository only encodes the parts of that policy that translate into
static documentation links (`kubernetes.io` + task-specific tool docs).
The permission to consult `/usr/share`/man pages and installed packages on
the box you're actually working from is real but isn't a URL — nothing to
list here, just keep it in mind while working through a lab.

## Always permitted

- https://kubernetes.io/docs/ — the core Kubernetes documentation: Services,
  NetworkPolicy, DNS, EndpointSlices, scheduling, debugging.
- https://kubernetes.io/blog/ — official Kubernetes project blog.

## Tool-specific (only when the task is about that tool)

| Tool | Docs root |
| --- | --- |
| Cilium / Hubble | https://docs.cilium.io/en/stable/ |
| Istio | https://istio.io/latest/docs/ |
| Envoy | https://www.envoyproxy.io/docs/envoy/latest/ |
| Gateway API | https://gateway-api.sigs.k8s.io/ |
| Prometheus | https://prometheus.io/docs/ |
| Helm | https://helm.sh/docs/ |
| Jaeger | https://www.jaegertracing.io/docs/ |
| cert-manager | https://cert-manager.io/docs/ |

## Rule of thumb used across every lab

- At most 5 links per `quick-reference.md`, and only the ones directly
  relevant to that specific task — not a general "here's the whole docs
  site" dump.
- A link is included only when the author is confident it is real and
  correctly targeted; when in doubt, fewer (correct) links beat more
  (possibly wrong) ones. Every link in this repository has been fetched
  live and confirmed to return HTTP 200.
- `docs/command-reference.md` in this repository is NOT exam documentation
  — it is a local cheat-sheet for practicing outside exam conditions
  (`make learn LAB=...`), not something referenced from `quick-reference.md`
  or available in exam mode (`make exam LAB=...`).
