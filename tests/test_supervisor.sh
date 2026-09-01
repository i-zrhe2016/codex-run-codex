#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home" "$tmp/workdir"
: > "$tmp/log"

FAKE_CODEX_COUNT_FILE="$tmp/count" \
FAKE_CODEX_LOG_FILE="$tmp/log" \
FAKE_CODEX_INITIAL_EXIT=1 \
FAKE_CODEX_RESUME_EXIT=0 \
CODEX_BIN="$ROOT/tests/fixtures/fake-codex" \
CODEX_HOME="$tmp/home" \
CODEX_WORKDIR="$tmp/workdir" \
CODEX_MODE=interactive \
CODEX_MAX_RETRIES=2 \
CODEX_RETRY_DELAY_SECONDS=0 \
CODEX_MAX_RETRY_DELAY_SECONDS=1 \
CODEX_CONTINUE_PROMPT='继续' \
"$ROOT/scripts/codex-supervisor.sh" > "$tmp/output" 2>&1

[ "$(sed -n '1p' "$tmp/count")" = 2 ]
grep -F -- '--last' "$tmp/log" >/dev/null
grep -F -- '继续' "$tmp/log" >/dev/null
[ "$(sed -n '1p' "$tmp/home/.codex-run-codex.state")" = completed ]

printf 'active\n' > "$tmp/home/.codex-run-codex.state"
printf '0\n' > "$tmp/count"
: > "$tmp/log"
FAKE_CODEX_COUNT_FILE="$tmp/count" \
FAKE_CODEX_LOG_FILE="$tmp/log" \
FAKE_CODEX_INITIAL_EXIT=99 \
FAKE_CODEX_RESUME_EXIT=0 \
CODEX_BIN="$ROOT/tests/fixtures/fake-codex" \
CODEX_HOME="$tmp/home" \
CODEX_WORKDIR="$tmp/workdir" \
CODEX_MODE=interactive \
CODEX_MAX_RETRIES=1 \
CODEX_RETRY_DELAY_SECONDS=0 \
CODEX_MAX_RETRY_DELAY_SECONDS=1 \
CODEX_CONTINUE_PROMPT='继续' \
"$ROOT/scripts/codex-supervisor.sh" > "$tmp/output" 2>&1

[ "$(sed -n '1p' "$tmp/count")" = 1 ]
grep -F -- 'resume' "$tmp/log" >/dev/null
[ "$(sed -n '1p' "$tmp/home/.codex-run-codex.state")" = completed ]

printf '0\n' > "$tmp/count"
: > "$tmp/log"
printf 'interrupted\n' > "$tmp/home/.codex-run-codex.state"
FAKE_CODEX_COUNT_FILE="$tmp/count" \
FAKE_CODEX_LOG_FILE="$tmp/log" \
FAKE_CODEX_INITIAL_EXIT=130 \
FAKE_CODEX_RESUME_EXIT=0 \
CODEX_BIN="$ROOT/tests/fixtures/fake-codex" \
CODEX_HOME="$tmp/home" \
CODEX_WORKDIR="$tmp/workdir" \
CODEX_MODE=interactive \
CODEX_MAX_RETRIES=1 \
CODEX_RETRY_DELAY_SECONDS=0 \
CODEX_MAX_RETRY_DELAY_SECONDS=1 \
"$ROOT/scripts/codex-supervisor.sh" > "$tmp/output" 2>&1

[ "$(sed -n '1p' "$tmp/count")" = 1 ]
[ "$(sed -n '1p' "$tmp/home/.codex-run-codex.state")" = interrupted ]

printf 'supervisor retry test: ok\n'
