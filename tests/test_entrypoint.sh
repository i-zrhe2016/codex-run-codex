#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home" "$tmp/workdir"
: > "$tmp/log"

FAKE_CODEX_COUNT_FILE="$tmp/count" \
FAKE_CODEX_LOG_FILE="$tmp/log" \
FAKE_CODEX_INITIAL_EXIT=0 \
CODEX_BIN="$ROOT/tests/fixtures/fake-codex" \
CODEX_HOME="$tmp/home" \
CODEX_WORKDIR="$tmp/workdir" \
CODEX_MODE=interactive \
CODEX_ACTION=start \
CODEX_PROMPT='检查当前工作区' \
CODEX_SANDBOX=workspace-write \
CODEX_APPROVAL_POLICY=on-request \
"$ROOT/scripts/codex-entrypoint.sh" > "$tmp/start-output" 2>&1

grep -F -- '--cd' "$tmp/log" >/dev/null
grep -F -- '检查当前工作区' "$tmp/log" >/dev/null
! grep -F -- 'resume' "$tmp/log" >/dev/null

: > "$tmp/log"
FAKE_CODEX_COUNT_FILE="$tmp/count" \
FAKE_CODEX_LOG_FILE="$tmp/log" \
FAKE_CODEX_RESUME_EXIT=0 \
CODEX_BIN="$ROOT/tests/fixtures/fake-codex" \
CODEX_HOME="$tmp/home" \
CODEX_WORKDIR="$tmp/workdir" \
CODEX_MODE=exec \
CODEX_ACTION=resume \
CODEX_CONTINUE_PROMPT='继续执行' \
"$ROOT/scripts/codex-entrypoint.sh" > "$tmp/resume-output" 2>&1

grep -F -- 'resume' "$tmp/log" >/dev/null
grep -F -- '--last' "$tmp/log" >/dev/null
grep -F -- '继续执行' "$tmp/log" >/dev/null

if CODEX_BIN="$ROOT/tests/fixtures/fake-codex" \
    CODEX_HOME="$tmp/home" \
    CODEX_WORKDIR="$tmp/workdir" \
    CODEX_ACTION=invalid \
    "$ROOT/scripts/codex-entrypoint.sh" > "$tmp/invalid-output" 2>&1; then
    exit 1
fi
grep -F -- 'CODEX_ACTION must be start or resume' "$tmp/invalid-output" >/dev/null

printf 'entrypoint action test: ok\n'
