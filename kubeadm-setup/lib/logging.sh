#!/usr/bin/env bash
# Shared logging helpers. Source this file; do not execute it directly.
#
# Never echo secrets, tokens, or private key material through these helpers.

if [[ -t 1 ]]; then
  readonly LOG_COLOR_RESET="\033[0m"
  readonly LOG_COLOR_INFO="\033[36m"
  readonly LOG_COLOR_WARN="\033[33m"
  readonly LOG_COLOR_ERROR="\033[31m"
  readonly LOG_COLOR_OK="\033[32m"
else
  readonly LOG_COLOR_RESET=""
  readonly LOG_COLOR_INFO=""
  readonly LOG_COLOR_WARN=""
  readonly LOG_COLOR_ERROR=""
  readonly LOG_COLOR_OK=""
fi

log_step() {
  printf '\n%s==> %s%s\n' "$LOG_COLOR_INFO" "$*" "$LOG_COLOR_RESET" >&2
}

log_info() {
  printf '%s[INFO]%s  %s\n' "$LOG_COLOR_INFO" "$LOG_COLOR_RESET" "$*" >&2
}

log_ok() {
  printf '%s[OK]%s    %s\n' "$LOG_COLOR_OK" "$LOG_COLOR_RESET" "$*" >&2
}

log_warn() {
  printf '%s[WARN]%s  %s\n' "$LOG_COLOR_WARN" "$LOG_COLOR_RESET" "$*" >&2
}

log_error() {
  printf '%s[ERROR]%s %s\n' "$LOG_COLOR_ERROR" "$LOG_COLOR_RESET" "$*" >&2
}

log_fatal() {
  log_error "$*"
  exit 1
}
