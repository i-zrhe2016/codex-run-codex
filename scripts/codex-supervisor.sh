#!/bin/sh
set -eu

log() {
    printf '[codex-supervisor] %s\n' "$*" >&2
}

fail() {
    printf '[codex-supervisor] ERROR: %s\n' "$*" >&2
    exit 64
}

CODEX_BIN=${CODEX_BIN:-codex}
CODEX_HOME=${CODEX_HOME:-/home/node/.codex}
CODEX_WORKDIR=${CODEX_WORKDIR:-/workspace}
CODEX_MODE=${CODEX_MODE:-interactive}
CODEX_PROMPT=${CODEX_PROMPT:-}
CODEX_CONTINUE_PROMPT=${CODEX_CONTINUE_PROMPT:-继续}
CODEX_SANDBOX=${CODEX_SANDBOX:-workspace-write}
CODEX_APPROVAL_POLICY=${CODEX_APPROVAL_POLICY:-on-request}
CODEX_MAX_RETRIES=${CODEX_MAX_RETRIES:-0}
CODEX_RETRY_DELAY_SECONDS=${CODEX_RETRY_DELAY_SECONDS:-5}
CODEX_MAX_RETRY_DELAY_SECONDS=${CODEX_MAX_RETRY_DELAY_SECONDS:-60}
CODEX_RESET_SESSION=${CODEX_RESET_SESSION:-0}
STATE_FILE=${CODEX_STATE_FILE:-$CODEX_HOME/.codex-run-codex.state}

case "$CODEX_MODE" in
    interactive|exec) ;;
    *) fail "CODEX_MODE must be interactive or exec" ;;
esac

case "$CODEX_MAX_RETRIES" in
    ''|*[!0-9]*) fail "CODEX_MAX_RETRIES must be a non-negative integer" ;;
esac
case "$CODEX_RETRY_DELAY_SECONDS" in
    ''|*[!0-9]*) fail "CODEX_RETRY_DELAY_SECONDS must be a non-negative integer" ;;
esac
case "$CODEX_MAX_RETRY_DELAY_SECONDS" in
    ''|*[!0-9]*) fail "CODEX_MAX_RETRY_DELAY_SECONDS must be a non-negative integer" ;;
esac
case "$CODEX_RESET_SESSION" in
    0|1) ;;
    *) fail "CODEX_RESET_SESSION must be 0 or 1" ;;
esac

command -v "$CODEX_BIN" >/dev/null 2>&1 || fail "Codex CLI not found: $CODEX_BIN"
mkdir -p "$CODEX_HOME" "$CODEX_WORKDIR"
state_dir=$(dirname "$STATE_FILE")
mkdir -p "$state_dir"

write_state() {
    state=$1
    state_tmp="$STATE_FILE.tmp.$$"
    printf '%s\n' "$state" > "$state_tmp"
    mv -f "$state_tmp" "$STATE_FILE"
    chmod 600 "$STATE_FILE" 2>/dev/null || true
}

if [ "$CODEX_RESET_SESSION" = 1 ]; then
    rm -f "$STATE_FILE"
fi

phase=start
if [ -f "$STATE_FILE" ] && [ "$(sed -n '1p' "$STATE_FILE")" = active ]; then
    phase=resume
    log "found an active session marker; attempting resume --last"
elif [ -f "$STATE_FILE" ] && [ "$(sed -n '1p' "$STATE_FILE")" = completed ]; then
    log "last session completed; set CODEX_RESET_SESSION=1 to start another one"
    exit 0
fi

if [ "$phase" = start ]; then
    # Mark the session before launching Codex so a container kill can resume it
    # on the next start instead of silently creating a second conversation.
    write_state active
fi

run_start() {
    if [ "$CODEX_MODE" = interactive ]; then
        if [ -n "$CODEX_PROMPT" ]; then
            "$CODEX_BIN" \
                --cd "$CODEX_WORKDIR" \
                --skip-git-repo-check \
                --sandbox "$CODEX_SANDBOX" \
                --ask-for-approval "$CODEX_APPROVAL_POLICY" \
                --no-alt-screen \
                "$@" \
                "$CODEX_PROMPT"
        else
            "$CODEX_BIN" \
                --cd "$CODEX_WORKDIR" \
                --skip-git-repo-check \
                --sandbox "$CODEX_SANDBOX" \
                --ask-for-approval "$CODEX_APPROVAL_POLICY" \
                --no-alt-screen \
                "$@"
        fi
    elif [ -n "$CODEX_PROMPT" ]; then
        "$CODEX_BIN" exec \
            --cd "$CODEX_WORKDIR" \
            --skip-git-repo-check \
            --sandbox "$CODEX_SANDBOX" \
            "$@" \
            "$CODEX_PROMPT"
    else
        "$CODEX_BIN" exec \
            --cd "$CODEX_WORKDIR" \
            --skip-git-repo-check \
            --sandbox "$CODEX_SANDBOX" \
            "$@"
    fi
}

run_resume() {
    if [ "$CODEX_MODE" = interactive ]; then
        "$CODEX_BIN" resume \
            --last \
            --cd "$CODEX_WORKDIR" \
            --no-alt-screen \
            "$CODEX_CONTINUE_PROMPT"
    else
        "$CODEX_BIN" exec resume \
            --last \
            --cd "$CODEX_WORKDIR" \
            --skip-git-repo-check \
            "$CODEX_CONTINUE_PROMPT"
    fi
}

attempt=0
while :; do
    if [ "$phase" = start ]; then
        log "starting Codex in ${CODEX_MODE} mode"
        if run_start "$@"; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        log "resuming the last Codex session with: ${CODEX_CONTINUE_PROMPT}"
        if run_resume; then
            exit_code=0
        else
            exit_code=$?
        fi
    fi

    if [ "$exit_code" -eq 0 ]; then
        write_state completed
        log "Codex exited normally; no continuation is needed"
        exit 0
    fi

    # Ctrl-C and SIGTERM represent an explicit stop, not an API outage.
    case "$exit_code" in
        130|143)
            write_state interrupted
            log "Codex was interrupted intentionally; automatic resume is disabled"
            exit 0
            ;;
    esac

    write_state active
    attempt=$((attempt + 1))
    if [ "$CODEX_MAX_RETRIES" -ne 0 ] && [ "$attempt" -gt "$CODEX_MAX_RETRIES" ]; then
        log "retry limit reached after ${attempt} failed recovery attempt(s)"
        exit "$exit_code"
    fi

    delay=$CODEX_RETRY_DELAY_SECONDS
    multiplier=1
    while [ "$multiplier" -lt "$attempt" ] && [ "$delay" -lt "$CODEX_MAX_RETRY_DELAY_SECONDS" ]; do
        if [ "$delay" -gt $((CODEX_MAX_RETRY_DELAY_SECONDS / 2)) ]; then
            delay=$CODEX_MAX_RETRY_DELAY_SECONDS
        else
            delay=$((delay * 2))
        fi
        multiplier=$((multiplier + 1))
    done
    if [ "$delay" -gt "$CODEX_MAX_RETRY_DELAY_SECONDS" ]; then
        delay=$CODEX_MAX_RETRY_DELAY_SECONDS
    fi
    log "Codex exited with ${exit_code}; retry ${attempt} in ${delay}s"
    if [ "$delay" -gt 0 ]; then
        sleep "$delay"
    fi
    phase=resume
done
