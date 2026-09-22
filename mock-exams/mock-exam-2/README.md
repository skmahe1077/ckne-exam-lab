# Mock Exam 2 — Troubleshooting-Focused (2 hours)

17 tasks, weighted by domain (Core Infra/CNI 3, Service Networking/DNS 4,
Advanced Traffic Management 3, Network Security/Policy 4, Observability 3 —
see `tasks.txt`), deliberately biased toward diagnostic/troubleshooting
tasks (broken-state labs, log/flow/metric investigation) rather than
build-from-scratch tasks.

```bash
./run-exam.sh start
./run-exam.sh status
./run-exam.sh score
./run-exam.sh cleanup
```

Or via `make`: `make mock-exam-2`. Passing target: 75%. Always run
`cleanup` when done.
