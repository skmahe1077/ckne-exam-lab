# CKNE Hands-On Practice

Hands-on practice labs, mock exams, and AWS/kubeadm cluster automation for
the [Certified Kubernetes Network Engineer (CKNE)](https://training.linuxfoundation.org/certification/certified-kubernetes-network-engineer-ckne/)
exam.

40 labs across the 5 CKNE domains, 3 timed mock exams, and shell-script-only
AWS infrastructure (VPC → EC2 → kubeadm → Cilium/Hubble/Gateway
API/Istio/Prometheus/Jaeger/cert-manager) — no Terraform, CloudFormation,
CDK, EKS, kind, Minikube, k3s, or MicroK8s anywhere in this repository.

> **Security note:** this repository's history previously contained a
> committed private key. It has been removed from the working tree and
> `.gitignore` now blocks `*.pem`/`*.key`/etc. If you are looking at a clone
> of this repo, read **[SECURITY-REMEDIATION.md](SECURITY-REMEDIATION.md)**
> before doing anything else — the corresponding AWS key pair must be
> rotated/deleted manually.

## Quick start

```bash
# 1. Configure
cp kubeadm-setup/config/cluster.env.example kubeadm-setup/config/cluster.env
$EDITOR kubeadm-setup/config/cluster.env

# 2. Create AWS infrastructure (idempotent — safe to re-run)
make aws-create

# 3. Bootstrap Kubernetes (kubeadm init/join, Cilium + Hubble)
make cluster-bootstrap

# 4. Install the remaining shared add-ons
make addons-install

# 5. Get kubectl access from your laptop
make kubeconfig
export KUBECONFIG=kubeadm-setup/ckne-cluster.kubeconfig

# 6. Verify
make cluster-verify

# 7. Run your first lab
make start    LAB=CNI-01
make validate LAB=CNI-01
make cleanup  LAB=CNI-01

# 8. When done practicing
make aws-stop            # pause (keep the instances, stop billing for compute)
# or:
make aws-destroy-dry-run # see exactly what would be deleted
make aws-destroy         # tear it all down (asks for confirmation)
```

See `kubeadm-setup/doc.md` for exactly what each step does and why, and run
`make help` for the full command list.

## Repository layout

```text
ckne-exam-practice/
├── kubeadm-setup/      AWS infra + kubeadm cluster automation (shell only)
├── labs/               40 hands-on labs across 5 CKNE domains
├── shared/              shared manifests, helper scripts, the lock mechanism
├── mock-exams/          3 timed mock exams
└── docs/                syllabus mapping, command reference, troubleshooting,
                          environment versions, learning progress, gaps
```

## Labs

See **[docs/syllabus-mapping.md](docs/syllabus-mapping.md)** for the full,
authoritative lab matrix (task IDs, namespaces, difficulty). Summary:

| Domain | Weight | Labs | Difficulty split |
| --- | ---: | ---: | --- |
| Core Infrastructure and CNI | 15% | 6 | 2 beginner / 3 intermediate / 1 advanced |
| Service Networking and DNS | 25% | 10 | 2 beginner / 6 intermediate / 2 advanced |
| Advanced Traffic Management | 20% | 8 | 1 beginner / 4 intermediate / 3 advanced |
| Network Security and Policy | 25% | 10 | 2 beginner / 5 intermediate / 3 advanced |
| Observability | 15% | 6 | 1 beginner / 2 intermediate / 3 advanced |
| **Total** | **100%** | **40** | **8 beginner / 20 intermediate / 12 advanced** |

Every lab has its own `README.md`, `concept.md`, `task.md`,
`quick-reference.md` (exam-permitted documentation only — see
`docs/documentation-index.md`), `setup.sh`, `validate.sh`, `cleanup.sh`,
`reset.sh`, `hints.md`, and `solution.md`, and runs in its own namespace
(`ckne-<domain>-<NN>`) so labs never overlap or leave state that breaks
another lab.

```bash
make learn LAB=CNI-01              # concept + task + quick reference
make exam  LAB=CNI-01              # task only — no hints/solution (real exam conditions)
make hint  LAB=CNI-01 LEVEL=1
make solution LAB=CNI-01
make reset LAB=CNI-01              # cleanup, then set back up
```

A small number of labs modify a genuinely shared/cluster-scoped resource
(CoreDNS, the Cilium Helm release, Istio mesh config) and use the locking
mechanism in `shared/scripts/lock.sh` to guarantee mutual exclusion and full
restoration on cleanup — see `docs/syllabus-mapping.md` for which ones.
`make active-labs` shows any currently-held lock; `make release-stale-lock
LAB=<id>` force-releases one (only ever do this deliberately, as a human
decision — see the lock's own refusal message for why).

## Mock exams

| Exam | Tasks | Focus | Time |
| --- | ---: | --- | --- |
| [Mock Exam 1](mock-exams/mock-exam-1/) | 15 | Intermediate | 2 hours |
| [Mock Exam 2](mock-exams/mock-exam-2/) | 17 | Troubleshooting-focused | 2 hours |
| [Mock Exam 3](mock-exams/mock-exam-3/) | 20 | Exam difficulty | 2 hours |

```bash
make mock-exam-1   # or ./mock-exams/mock-exam-1/run-exam.sh {start|status|score|cleanup}
```

75% is this repository's practice pass target, matching each exam's own
scoring output.

## Validation status

No AWS resources were provisioned or destroyed while building this
repository (per its own design constraints), so nothing here has been
exercised end-to-end against a live cluster. What *has* been verified:

- Every shell script (184 total) passes `bash -n` and `shellcheck` at
  warning severity, and is confirmed bash-3.2-compatible (macOS's default
  `/bin/bash`) — no `mapfile`, associative arrays, or namerefs.
- Every YAML manifest (134 files) parses cleanly.
- All 40 labs' `task.md` (Task ID, Namespace, Difficulty) match
  `docs/syllabus-mapping.md` exactly, and match the `TASK_ID`/`NAMESPACE`
  constants in their own `setup.sh`/`validate.sh`/`cleanup.sh` — no
  duplicates, no drift.
- Domain distribution (6/10/8/10/6) and difficulty distribution
  (8/20/12) both match the design brief exactly.
- Every manifest placeholder (`${NAMESPACE}`, `${TASK_ID}`, ...) has a
  corresponding substitution in its lab's `setup.sh`.
- All 78 unique documentation links across every `quick-reference.md`
  were fetched live and confirmed to return HTTP 200 (several stale
  Gateway API / Cilium doc paths were found and fixed this way).
- No lab uses the `default` namespace; every object carries the required
  `app.kubernetes.io/part-of`/`ckne.openai.com/lab-id` labels; no
  `cleanup.sh` contains a forbidden broad-deletion pattern.
- `make exam`/`make learn`/`make hint`/`make solution` were smoke-tested
  against labs built by different authors (agents) and behave correctly —
  exam mode shows only the task and quick reference, hints extract the
  correct level, etc.

What has **not** been verified (would require live AWS + a real cluster):
runtime execution of any `setup.sh`/`validate.sh`/`cleanup.sh` against
actual cluster state, the AWS provisioning/teardown scripts themselves,
and the mock-exam runners' `score`/`cleanup` subcommands. See
`docs/coverage-gaps.md` for known scope limitations discovered while
writing the labs (no cloud LoadBalancer controller, single-cluster
constraints on the cross-cluster labs, etc.).

## Documentation

- [docs/syllabus-mapping.md](docs/syllabus-mapping.md) — the authoritative lab matrix
- [docs/documentation-index.md](docs/documentation-index.md) — exam-permitted documentation allow-list
- [docs/command-reference.md](docs/command-reference.md) — learning-mode command cheat-sheet
- [docs/troubleshooting-workflow.md](docs/troubleshooting-workflow.md) — the diagnostic order that pays off
- [docs/environment-versions.md](docs/environment-versions.md) — exact installed versions
- [docs/learning-progress.md](docs/learning-progress.md) — personal progress checklist
- [docs/coverage-gaps.md](docs/coverage-gaps.md) — honest known limitations (single cluster, no cloud LB, etc.)
- [kubeadm-setup/doc.md](kubeadm-setup/doc.md) — full infrastructure/bootstrap walkthrough
- [SECURITY-REMEDIATION.md](SECURITY-REMEDIATION.md) — exposed-key remediation steps (read this first)

## License

[MIT](LICENSE)
