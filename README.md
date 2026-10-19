# Claude Code Docker

Run Claude Code CLI in a container with persistent auth and shared project memory.

## Quick Start

```bash
./run.sh
```

Or with docker-compose:

```bash
cp .env.example .env
# Edit .env with your settings
docker-compose run --rm claude
```

## Configuration

Copy `.env.example` to `.env` and adjust:

| Variable | Default | Description |
|-|-|-|
| `USERNAME` | dev | Container username |
| `USER_HOME` | /home/dev | Home path (match host for consistent paths) |
| `USER_UID` | 1000 | User ID (match host for file permissions) |
| `USER_GID` | 1000 | Group ID |
| `HOST_CODE_DIR` | ~/code | Code directory to mount |
| `HOST_CLAUDE_PROJECTS` | ~/.claude/projects | Shared projects memory |
| `CLAUDE_FLAGS` | (empty) | Extra flags for claude |

### macOS Example

```bash
USERNAME=yourname
USER_HOME=/Users/yourname
USER_UID=501
USER_GID=20
```

## Passing Flags

Pass flags via `CLAUDE_FLAGS` env var or directly:

```bash
# Via env var
CLAUDE_FLAGS="--dangerously-skip-permissions" ./run.sh

# Direct
./run.sh --dangerously-skip-permissions

# In .env
CLAUDE_FLAGS=--dangerously-skip-permissions
```

Common flags:
- `--dangerously-skip-permissions` - Skip all permission prompts
- `--allowedTools "Bash,Read,Edit"` - Whitelist specific tools
- `--model sonnet` - Use a specific model

## Mount Strategy

- **claude-data volume**: Container's own `.claude` (sessions, cache, state)
- **projects bind mount**: Shared across hosts - Claude remembers your projects everywhere
- **code bind mount**: Your work directories

## Multi-arch Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t claude-code:latest .
```

## First Run

On first run, Claude will prompt for authentication. The auth token persists in the `claude-data` volume.

## Running on Another Device

1. Copy this directory to the other device
2. Sync `~/.claude/projects` (rsync, syncthing, NFS, whatever)
3. Run `./run.sh` - auth once, then you're set

## Kubernetes

Deploy to a cluster:

```bash
# Deploy
kubectl apply -k k8s/

# First time: login to authenticate
kubectl exec -it -n claude claude-0 -- claude login

# Restart pod to start remote-control server
kubectl rollout restart statefulset -n claude claude
```

The pod runs `claude remote-control --spawn worktree` which:
- Accepts up to 32 concurrent sessions
- Each session gets its own git worktree (isolated)
- Connect from any device via claude.ai or `claude --connect`

To enable flags, edit the `CLAUDE_FLAGS` env var in `k8s/statefulset.yaml`.

Check logs for the session URL:
```bash
kubectl logs -n claude claude-0
```

For code access, replace the `emptyDir` volume with a PVC or NFS mount.
