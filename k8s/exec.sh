#!/usr/bin/env bash
# Exec into the claude pod
set -euo pipefail

NAMESPACE="${NAMESPACE:-claude}"
POD="${POD:-claude-0}"

if [ "${1:-}" = "login" ]; then
    exec kubectl exec -it -n "$NAMESPACE" "$POD" -- claude login
elif [ "${1:-}" = "logs" ]; then
    exec kubectl logs -f -n "$NAMESPACE" "$POD"
elif [ "${1:-}" = "restart" ]; then
    exec kubectl rollout restart statefulset -n "$NAMESPACE" claude
else
    exec kubectl exec -it -n "$NAMESPACE" "$POD" -- claude "$@"
fi
