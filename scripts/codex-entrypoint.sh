#!/bin/sh
set -eu

log() {
    printf '[codex-entrypoint] %s\n' "$*" >&2
}

fail() {
    printf '[codex-entrypoint] ERROR: %s\n' "$*" >&2
    exit 64
}

CODEX_HOME=${CODEX_HOME:-/home/node/.codex}
CONFIG_MODE=${CODEX_CONFIG_MODE:-env}
PROVIDER=${CODEX_MODEL_PROVIDER:-custom}
BASE_URL=${CODEX_PROVIDER_BASE_URL:-}
WIRE_API=${CODEX_PROVIDER_WIRE_API:-responses}
REQUIRES_AUTH=${CODEX_PROVIDER_REQUIRES_OPENAI_AUTH:-true}
MODEL=${CODEX_MODEL:-}

case "$CONFIG_MODE" in
    env|preserve) ;;
    *) fail "CODEX_CONFIG_MODE must be env or preserve" ;;
esac

mkdir -p "$CODEX_HOME"
chmod 700 "$CODEX_HOME" 2>/dev/null || true
umask 077

single_line() {
    value=$1
    compact=$(printf '%s' "$value" | tr -d '\r\n')
    [ "$compact" = "$value" ] || fail "provider configuration values must be single-line strings"
}

toml_quote() {
    value=$1
    single_line "$value"
    escaped=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '"%s"' "$escaped"
}

if [ -n "$BASE_URL" ] && [ "$CONFIG_MODE" = env ]; then
    case "$PROVIDER" in
        ''|*[!A-Za-z0-9_-]*) fail "CODEX_MODEL_PROVIDER may contain only letters, numbers, _ and -" ;;
    esac
    case "$BASE_URL" in
        http://*|https://*) ;;
        *) fail "CODEX_PROVIDER_BASE_URL must start with http:// or https://" ;;
    esac
    case "$WIRE_API" in
        responses|chat) ;;
        *) fail "CODEX_PROVIDER_WIRE_API must be responses or chat" ;;
    esac
    case "$REQUIRES_AUTH" in
        true|false) ;;
        *) fail "CODEX_PROVIDER_REQUIRES_OPENAI_AUTH must be true or false" ;;
    esac
    single_line "$MODEL"

    config_tmp="$CODEX_HOME/.config.toml.tmp.$$"
    {
        printf 'model_provider = %s\n' "$(toml_quote "$PROVIDER")"
        if [ -n "$MODEL" ]; then
            printf 'model = %s\n' "$(toml_quote "$MODEL")"
        fi
        printf '\n[model_providers.%s]\n' "$(toml_quote "$PROVIDER")"
        printf 'name = %s\n' "$(toml_quote "$PROVIDER")"
        printf 'base_url = %s\n' "$(toml_quote "$BASE_URL")"
        printf 'wire_api = %s\n' "$(toml_quote "$WIRE_API")"
        printf 'requires_openai_auth = %s\n' "$REQUIRES_AUTH"
    } > "$config_tmp"
    mv -f "$config_tmp" "$CODEX_HOME/config.toml"
    chmod 600 "$CODEX_HOME/config.toml"
    log "generated provider configuration for ${PROVIDER} (${WIRE_API})"
elif [ -n "$BASE_URL" ]; then
    log "preserving existing config.toml because CODEX_CONFIG_MODE=preserve"
fi

api_key=${CODEX_API_KEY:-}
api_key_file=${CODEX_API_KEY_FILE:-}
if [ -n "$api_key_file" ] && [ -r "$api_key_file" ]; then
    file_key=$(tr -d '\r\n' < "$api_key_file")
    if [ -n "$file_key" ]; then
        api_key=$file_key
    fi
fi

if [ -n "$api_key" ]; then
    auth_tmp="$CODEX_HOME/.auth.json.tmp.$$"
    CODEX_API_KEY_VALUE=$api_key node -e \
        'process.stdout.write(JSON.stringify({OPENAI_API_KEY: process.env.CODEX_API_KEY_VALUE}) + "\n")' \
        > "$auth_tmp"
    mv -f "$auth_tmp" "$CODEX_HOME/auth.json"
    chmod 600 "$CODEX_HOME/auth.json"
    log "updated Codex API-key authentication in the persistent CODEX_HOME"
fi

if [ ! -f "$CODEX_HOME/config.toml" ] && [ -z "$BASE_URL" ]; then
    log "no config.toml found; set CODEX_PROVIDER_BASE_URL or mount a config"
fi

exec /usr/local/bin/codex-supervisor "$@"
