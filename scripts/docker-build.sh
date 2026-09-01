#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    printf 'usage: %s <image:tag> [context]\n' "$0" >&2
    exit 64
fi

image=$1
context=${2:-.}
builder=${DOCKER_BUILDER:-elastic-builder}
cpu_shares=${DOCKER_CPU_SHARES:-256}
platform=${DOCKER_PLATFORM:-linux/amd64}

if ! docker buildx inspect "$builder" >/dev/null 2>&1; then
    docker buildx create \
        --name "$builder" \
        --driver docker-container \
        --driver-opt "cpu-shares=${cpu_shares}" \
        --use
else
    docker buildx use "$builder"
fi

docker buildx build \
    --builder "$builder" \
    --platform "$platform" \
    --load \
    --tag "$image" \
    "$context"
