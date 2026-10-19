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
: "${USERNAME:=jaenster}"
: "${USER_HOME:=/Users/jaenster}"
: "${USER_UID:=$(id -u)}"
: "${USER_GID:=$(id -g)}"
: "${IMAGE_NAME:=claudainer}"
: "${IMAGE_TAG:=latest}"
: "${VOLUME_NAME:=claude-data}"
: "${HOST_CODE_DIR:=$HOME/code}"
: "${HOST_CLAUDE_PROJECTS:=$HOME/.claude/projects}"
: "${CLAUDE_FLAGS:=}"

# Working directory: use argument, or current dir if under code dir, or code dir
if [ -n "${1:-}" ] && [ -d "$1" ]; then
    WORKDIR="$(cd "$1" && pwd)"
    shift
elif [[ "$(pwd)" == "${HOST_CODE_DIR}"* ]]; then
    WORKDIR="$(pwd)"
else
    WORKDIR="${USER_HOME}/code"
fi

# Map host path to container path
CONTAINER_WORKDIR="${WORKDIR/#$HOME/$USER_HOME}"

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
    -w "$CONTAINER_WORKDIR" \
    -v "${VOLUME_NAME}:${USER_HOME}/.claude" \
    -v "${HOST_CLAUDE_PROJECTS}:${USER_HOME}/.claude/projects" \
    -v "${HOST_CODE_DIR}:${USER_HOME}/code" \
    -v "${HOME}/.ssh:${USER_HOME}/.ssh:ro" \
    -v "${HOME}/.gitconfig:${USER_HOME}/.gitconfig:ro" \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    "$IMAGE" \
    $CLAUDE_FLAGS "$@"
