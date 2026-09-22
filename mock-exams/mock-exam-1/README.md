# Mock Exam 1 — Intermediate (2 hours)

15 tasks, weighted by domain the same way the real CKNE domain weights are
distributed (Core Infra/CNI 2, Service Networking/DNS 4, Advanced Traffic
Management 3, Network Security/Policy 4, Observability 2 — see `tasks.txt`).
Overall difficulty: intermediate.

```bash
./run-exam.sh start      # sets up all 15 task environments, prints each task + quick reference, starts the timer
./run-exam.sh status      # elapsed / remaining time
./run-exam.sh score       # runs each task's real validator, prints PASS/FAIL per task + total score
./run-exam.sh cleanup     # tears down every task environment for this exam
```

Or via `make`: `make mock-exam-1`.

No hints or solutions are shown during the exam — only each task's
`task.md` and `quick-reference.md`, exactly like `make exam LAB=...`. Passing
target is 75%, matching this repository's practice pass bar. Always run
`cleanup` when you're done, even if you stop partway through.
