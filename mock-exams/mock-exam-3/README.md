# Mock Exam 3 — Exam Difficulty (2 hours)

20 tasks, weighted by domain (Core Infra/CNI 3, Service Networking/DNS 5,
Advanced Traffic Management 4, Network Security/Policy 5, Observability 3 —
see `tasks.txt`), spanning beginner through advanced difficulty — the
closest approximation of real exam breadth and pacing pressure in this
repository.

```bash
./run-exam.sh start
./run-exam.sh status
./run-exam.sh score
./run-exam.sh cleanup
```

Or via `make`: `make mock-exam-3`. Passing target: 75%. Always run
`cleanup` when done.
