# Claudainer

Full-stack dev environment with Claude Code CLI in Docker/Kubernetes.

## What's Included

| Category | Tools |
|-|-|
| **Languages** | Node.js 22, Python 3, Go 1.23, Rust, Zig 0.13 |
| **Build** | gcc, g++, make, cmake, pkg-config, autoconf |
| **CLI** | jq, yq, vim, neovim, tmux, htop, ripgrep, fzf, bat, fd |
| **Cloud/K8s** | kubectl, helm, terraform, docker CLI |
| **Dev** | git, gh (GitHub CLI), ssh |
| **AI** | Claude Code (native binary) |

## Quick Start

```bash
./run.sh
```

Or with docker-compose:

```bash
cp .env.example .env
docker-compose run --rm claude
```

## Configuration

Copy `.env.example` to `.env` and adjust:

| Variable | Default | Description |
|-|-|-|
| `USERNAME` | dev | Container username |
| `USER_HOME` | /home/dev | Home path |
| `USER_UID` | 1000 | User ID (match host) |
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

```bash
# Via env var
CLAUDE_FLAGS="--dangerously-skip-permissions" ./run.sh

# Direct
./run.sh --dangerously-skip-permissions
```

Common flags:
- `--dangerously-skip-permissions` - Skip all permission prompts
- `--allowedTools "Bash,Read,Edit"` - Whitelist specific tools
- `--model sonnet` - Use a specific model

## Docker-out-of-Docker

The container mounts `/var/run/docker.sock` so you can run docker commands from inside:

```bash
docker ps  # works inside the container
```

## Multi-arch Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t claudainer:latest .
```

## Pre-authenticated Containers

Option 1: Mount credentials (uncomment in docker-compose.yml):
```yaml
- ~/.claude/credentials.json:/home/dev/.claude/credentials.json:ro
```

Option 2: Login once, credentials persist in volume:
```bash
./run.sh login
```

## Kubernetes

```bash
kubectl apply -k k8s/

# First time: login
kubectl exec -it -n claude claude-0 -- claude login

# Restart to start remote-control server
kubectl rollout restart statefulset -n claude claude
```

The pod runs `claude remote-control --spawn worktree`:
- Up to 32 concurrent sessions
- Each session gets isolated git worktree
- Connect from any device via claude.ai

## Version Pinning

Build args for specific versions:

```bash
docker build \
  --build-arg NODE_VERSION=22 \
  --build-arg GO_VERSION=1.23.2 \
  --build-arg ZIG_VERSION=0.13.0 \
  -t claudainer:latest .
```
