#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Defaults - override via environment or .env file
: "${USERNAME:=dev}"
: "${USER_HOME:=/home/dev}"
: "${USER_UID:=$(id -u)}"
: "${USER_GID:=$(id -g)}"
: "${IMAGE_NAME:=claude-code}"
: "${IMAGE_TAG:=latest}"
: "${VOLUME_NAME:=claude-data}"
: "${HOST_CODE_DIR:=$HOME/code}"
: "${HOST_CLAUDE_PROJECTS:=$HOME/.claude/projects}"
: "${CLAUDE_FLAGS:=}"

IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Build if image doesn't exist
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Building image..."
    docker build \
        --build-arg USERNAME="$USERNAME" \
        --build-arg USER_HOME="$USER_HOME" \
        --build-arg USER_UID="$USER_UID" \
        --build-arg USER_GID="$USER_GID" \
        -t "$IMAGE" \
        "$SCRIPT_DIR"
fi

# Create volume if it doesn't exist
docker volume create "$VOLUME_NAME" &>/dev/null || true

# shellcheck disable=SC2086
exec docker run -it --rm \
    --hostname claude-docker \
    -v "${VOLUME_NAME}:${USER_HOME}/.claude" \
    -v "${HOST_CLAUDE_PROJECTS}:${USER_HOME}/.claude/projects" \
    -v "${HOST_CODE_DIR}:${USER_HOME}/code" \
    -v "${HOME}/.ssh:${USER_HOME}/.ssh:ro" \
    -v "${HOME}/.gitconfig:${USER_HOME}/.gitconfig:ro" \
    "$IMAGE" \
    $CLAUDE_FLAGS "$@"
