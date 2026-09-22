#!/usr/bin/env bash
# ==============================================================================
# Shared mock-exam runner engine. Sourced by each mock-exams/mock-exam-N/run-exam.sh,
# which must set EXAM_ID, EXAM_DIR, TIME_LIMIT_MINUTES, PASS_TARGET_PERCENT
# before sourcing this file, then call `mock_main "$@"`.
#
# Subcommands: start | status | score | cleanup
#
# State is kept per-exam under mock-exams/mock-exam-N/.exam-state/ (git-ignored
# runtime state, not exam content) so `score` after `start` can compute elapsed
# time, and so `cleanup` is safe to re-run.
# ==============================================================================
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "$REPO_ROOT/shared/scripts/lib.sh"

: "${EXAM_ID:?EXAM_ID must be set before sourcing mock-exam-runner.sh}"
: "${EXAM_DIR:?EXAM_DIR must be set before sourcing mock-exam-runner.sh}"
: "${TIME_LIMIT_MINUTES:?TIME_LIMIT_MINUTES must be set before sourcing mock-exam-runner.sh}"
: "${PASS_TARGET_PERCENT:?PASS_TARGET_PERCENT must be set before sourcing mock-exam-runner.sh}"

TASKS_FILE="$EXAM_DIR/tasks.txt"
STATE_DIR="$EXAM_DIR/.exam-state"
START_FILE="$STATE_DIR/start-time"

read_tasks() {
  grep -v '^\s*#' "$TASKS_FILE" | grep -v '^\s*$'
}

mock_start() {
  ckne_require_nodes_ready
  mkdir -p "$STATE_DIR"
  date -u +%s > "$START_FILE"
  echo "=============================================================="
  echo " $EXAM_ID — starting. Time limit: ${TIME_LIMIT_MINUTES} minutes."
  echo " Pass target: ${PASS_TARGET_PERCENT}%"
  echo "=============================================================="
  local count=0
  while IFS= read -r task_id; do
    count=$((count + 1))
    local dir
    dir="$(ckne_resolve_lab_dir "$task_id")"
    if [[ -z "$dir" ]]; then
      echo "WARN: no lab directory found for task $task_id — skipping" >&2
      continue
    fi
    echo ""
    echo "-------------------------------------------------------------"
    echo " Task $count: $task_id"
    echo "-------------------------------------------------------------"
    "$dir/setup.sh" >/dev/null
    cat "$dir/task.md"
    echo ""
    echo "Quick reference:"
    cat "$dir/quick-reference.md"
  done < <(read_tasks)
  echo ""
  echo "All ${count} task environments are set up. Timer is running."
  echo "Run: ./run-exam.sh status   |   ./run-exam.sh score   |   ./run-exam.sh cleanup"
}

mock_status() {
  if [[ ! -f "$START_FILE" ]]; then
    echo "Exam not started. Run: ./run-exam.sh start"
    return 1
  fi
  local start now elapsed_min remaining_min
  start="$(cat "$START_FILE")"
  now="$(date -u +%s)"
  elapsed_min=$(( (now - start) / 60 ))
  remaining_min=$(( TIME_LIMIT_MINUTES - elapsed_min ))
  echo "Elapsed: ${elapsed_min} min / ${TIME_LIMIT_MINUTES} min (remaining: ${remaining_min} min)"
  if [[ "$remaining_min" -lt 0 ]]; then
    echo "Time limit exceeded."
  fi
}

mock_score() {
  if [[ ! -f "$START_FILE" ]]; then
    echo "Exam not started. Run: ./run-exam.sh start"
    return 1
  fi
  mock_status || true
  echo ""
  echo "=============================================================="
  echo " Scoring $EXAM_ID"
  echo "=============================================================="

  local total=0 passed=0
  local domain_names=""
  while IFS= read -r task_id; do
    local dir
    dir="$(ckne_resolve_lab_dir "$task_id")"
    if [[ -z "$dir" ]]; then
      echo "SKIP  $task_id (lab not found)"
      continue
    fi
    total=$((total + 1))
    local domain
    domain="$(basename "$(dirname "$dir")")"
    if "$dir/validate.sh" >/tmp/ckne-mockscore-$$.log 2>&1; then
      passed=$((passed + 1))
      printf 'PASS  %-10s %s\n' "$task_id" "$domain"
    else
      printf 'FAIL  %-10s %s\n' "$task_id" "$domain"
    fi
    rm -f /tmp/ckne-mockscore-$$.log
  done < <(read_tasks)

  echo "--------------------------------------------------------------"
  local pct=0
  if [[ "$total" -gt 0 ]]; then
    pct=$(( passed * 100 / total ))
  fi
  echo "Score: ${passed}/${total} (${pct}%) — pass target: ${PASS_TARGET_PERCENT}%"
  if [[ "$pct" -ge "$PASS_TARGET_PERCENT" ]]; then
    echo "RESULT: PASS"
  else
    echo "RESULT: BELOW TARGET"
  fi
  {
    echo "score=${passed}/${total}"
    echo "percent=${pct}"
    echo "target=${PASS_TARGET_PERCENT}"
  } > "$STATE_DIR/results.txt"
}

mock_cleanup() {
  echo "Cleaning up all $EXAM_ID task environments..."
  while IFS= read -r task_id; do
    local dir
    dir="$(ckne_resolve_lab_dir "$task_id")"
    [[ -z "$dir" ]] && continue
    "$dir/cleanup.sh" || echo "WARN: cleanup failed for $task_id" >&2
  done < <(read_tasks)
  rm -rf "$STATE_DIR"
  echo "Cleanup complete."
}

mock_main() {
  case "${1:-}" in
    start)   mock_start ;;
    status)  mock_status ;;
    score)   mock_score ;;
    cleanup) mock_cleanup ;;
    *)
      echo "Usage: $0 {start|status|score|cleanup}" >&2
      exit 1
      ;;
  esac
}
