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
# Build with your user/paths (one time)
docker build \
  --build-arg USERNAME=$(whoami) \
  --build-arg USER_HOME=$HOME \
  --build-arg USER_UID=$(id -u) \
  --build-arg USER_GID=$(id -g) \
  -t claudainer:latest .

# Run from any project directory
cd ~/code/my-project
claudainer
```

## Installation

### 1. Build the image

```bash
cd /path/to/claudainer
docker build \
  --build-arg USERNAME=$(whoami) \
  --build-arg USER_HOME=$HOME \
  --build-arg USER_UID=$(id -u) \
  --build-arg USER_GID=$(id -g) \
  -t claudainer:latest .
```

### 2. Create the alias

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias claudainer='/path/to/claudainer/run.sh'
```

Or create a symlink:

```bash
ln -s /path/to/claudainer/run.sh /usr/local/bin/claudainer
```

### 3. Use it

```bash
cd ~/code/my-project
claudainer                              # starts claude in current dir
claudainer --dangerously-skip-permissions  # with flags
claudainer ~/code/other-project         # explicit path
```

## How It Works

### Path Mapping

The container mirrors your host paths exactly:

| Host | Container |
|-|-|
| `/Users/jaenster` | `/Users/jaenster` |
| `/Users/jaenster/code/foo` | `/Users/jaenster/code/foo` |
| `~/.claude/projects` | `~/.claude/projects` |

This means Claude's file references work identically on host and in container.

### Working Directory

The `run.sh` script automatically:
1. Uses your current directory if it's under `~/code/`
2. Or accepts an explicit path as first argument
3. Falls back to `~/code` otherwise

### Volume Mounts

| Mount | Purpose |
|-|-|
| `claude-data` → `~/.claude` | Container's sessions, cache, auth |
| `~/.claude/projects` → `~/.claude/projects` | **Shared** project memory |
| `~/code` → `~/code` | Your code |
| `~/.ssh` | Git SSH keys (read-only) |
| `~/.gitconfig` | Git config (read-only) |
| `/var/run/docker.sock` | Docker-out-of-docker |

### Project Memory (`~/.claude/projects`)

This directory contains Claude's per-project memory (CLAUDE.md, settings, etc.).

**It's mounted directly from your host** — not inside the docker volume. This means:
- Project memory is shared between host Claude and container Claude
- Changes made in container are visible on host and vice versa
- Your project context persists across both environments

The container has its own `~/.claude` for sessions/cache (in a docker volume), but projects are shared.

## Configuration

Create `.env` file (optional):

```bash
# Override defaults
USERNAME=yourname
USER_HOME=/Users/yourname
HOST_CODE_DIR=~/code
HOST_CLAUDE_PROJECTS=~/.claude/projects

# Claude flags (always applied)
CLAUDE_FLAGS=--dangerously-skip-permissions
```

## Passing Flags

```bash
# Via argument
claudainer --dangerously-skip-permissions

# Via env var
CLAUDE_FLAGS="--dangerously-skip-permissions" claudainer

# Via .env file
echo 'CLAUDE_FLAGS=--dangerously-skip-permissions' >> .env
```

Common flags:
- `--dangerously-skip-permissions` - Skip all permission prompts
- `--allowedTools "Bash,Read,Edit"` - Whitelist specific tools
- `--model sonnet` - Use a specific model

## First Run / Authentication

On first run, Claude will prompt for login:

```bash
claudainer
# Follow the auth flow in your browser
```

Credentials are stored in the `claude-data` volume and persist across runs.

## Docker Hub

Pre-built images (generic, you'll want to rebuild for your paths):

```bash
docker pull jaenster/claudainer:latest
```

## Kubernetes

See `k8s/` directory for StatefulSet with remote-control mode.

```bash
kubectl apply -k k8s/
kubectl exec -it -n claude claude-0 -- claude login
kubectl rollout restart statefulset -n claude claude
```

## Version Pinning

```bash
docker build \
  --build-arg NODE_VERSION=22 \
  --build-arg GO_VERSION=1.23.2 \
  --build-arg ZIG_VERSION=0.13.0 \
  --build-arg USERNAME=$(whoami) \
  --build-arg USER_HOME=$HOME \
  -t claudainer:latest .
```
