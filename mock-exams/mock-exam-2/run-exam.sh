#!/usr/bin/env bash
set -Eeuo pipefail
EXAM_ID="Mock Exam 2 (Troubleshooting-Focused)"
EXAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIME_LIMIT_MINUTES=120
PASS_TARGET_PERCENT=75

REPO_ROOT="$(cd "$EXAM_DIR/../.." && pwd)"
# shellcheck source=../../shared/scripts/mock-exam-runner.sh
source "$REPO_ROOT/shared/scripts/mock-exam-runner.sh"
mock_main "$@"
