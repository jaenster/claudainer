#!/usr/bin/env bash
# Entrypoint for running claudainer as a long-lived Remote Control server (k8s).
set -euo pipefail

export PATH="/opt/claudainer/bin:$PATH"

: "${INSTANCE_NAME:=$(hostname)}"
: "${WORKSPACE:=$HOME/work}"
: "${REPO:=}"
: "${GIT_USER_NAME:=claude}"
: "${GIT_USER_EMAIL:=claude@localhost}"
: "${PERMISSION_MODE:=bypassPermissions}"
: "${SPAWN_MODE:=worktree}"
: "${SESSION_NAME_PREFIX:=$INSTANCE_NAME}"
: "${CLAUDAINER_CONFIG:=/etc/claudainer}"

mkdir -p "$WORKSPACE" "$HOME/.claude"

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global init.defaultBranch main
git config --global --replace-all credential.https://github.com.helper ''
git config --global --add credential.https://github.com.helper /opt/claudainer/bin/git-credential-github
git config --global url.https://github.com/.insteadOf git@github.com:

# Commit signing with an SSH key handed in through the secret (GIT_SIGNING_KEY, the private key).
if [ -n "${GIT_SIGNING_KEY:-}" ]; then
    key="$HOME/.ssh/signing_key"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    (umask 077 && printf '%s\n' "$GIT_SIGNING_KEY" > "$key")
    if ssh-keygen -y -f "$key" > "$key.pub" 2>/dev/null; then
        git config --global gpg.format ssh
        git config --global user.signingkey "$key"
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true
        printf '%s %s\n' "$GIT_USER_EMAIL" "$(cat "$key.pub")" > "$HOME/.ssh/allowed_signers"
        git config --global gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"
        echo "git: signing commits with $(ssh-keygen -lf "$key.pub" | cut -d' ' -f2)"
    else
        echo "git: GIT_SIGNING_KEY is not a usable private key (passphrase?), commits stay unsigned" >&2
    fi
fi

if [ -n "${GITHUB_PAT:-}${GITHUB_APP_ID:-}" ]; then
    if login=$(gh api /user --jq .login 2>/dev/null); then
        echo "github: authenticated as $login"
    elif gh api /installation/repositories --jq '.repositories[].full_name' >/dev/null 2>&1; then
        echo "github: authenticated as app $GITHUB_APP_ID"
    else
        echo "github: token rejected" >&2
    fi
else
    echo "github: no credentials (set GITHUB_PAT or GITHUB_APP_ID)" >&2
fi

# The instance's code: cloned once, after that it is the volume's to keep.
if [ -n "$REPO" ] && [ ! -d "$WORKSPACE/.git" ]; then
    git clone "$REPO" "$WORKSPACE"
fi
if [ "$SPAWN_MODE" = worktree ] && [ ! -d "$WORKSPACE/.git" ]; then
    echo "workspace: $WORKSPACE is not a git repo, spawning in same-dir mode"
    SPAWN_MODE=same-dir
fi

# Marketplaces, plugins and user-scope MCP servers from the mounted config (all idempotent).
#   marketplaces.txt  one source per line (owner/repo, URL or path)
#   plugins.txt       one plugin@marketplace per line
#   mcp.json          {"mcpServers": {"name": {...}}}
lines() { [ -f "$1" ] && grep -v '^\s*\(#\|$\)' "$1" || true; }

lines "$CLAUDAINER_CONFIG/marketplaces.txt" | while read -r source; do
    claude plugin marketplace add "$source" >/dev/null 2>&1 || echo "plugins: marketplace $source failed" >&2
done
[ -f "$CLAUDAINER_CONFIG/marketplaces.txt" ] && claude plugin marketplace update >/dev/null 2>&1 || true
lines "$CLAUDAINER_CONFIG/plugins.txt" | while read -r plugin; do
    claude plugin install --scope user "$plugin" >/dev/null 2>&1 || echo "plugins: install $plugin failed" >&2
done

if [ -f "$CLAUDAINER_CONFIG/mcp.json" ]; then
    jq -r '.mcpServers | keys[]' "$CLAUDAINER_CONFIG/mcp.json" | while read -r name; do
        claude mcp remove --scope user "$name" >/dev/null 2>&1 || true
        claude mcp add-json --scope user "$name" "$(jq -c --arg n "$name" '.mcpServers[$n]' "$CLAUDAINER_CONFIG/mcp.json")" >/dev/null \
            || echo "mcp: add $name failed" >&2
    done
fi

# Hooks and settings from the mounted config (flat ConfigMap keys):
#   claude-hook-<name>  -> ~/.claude/hooks/<name>
#   git-hook-<name>     -> ~/.config/git/hooks/<name>, used as the global core.hooksPath
#   settings.json       -> merged over ~/.claude/settings.json
for f in "$CLAUDAINER_CONFIG"/claude-hook-* "$CLAUDAINER_CONFIG"/git-hook-*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    case "$name" in
        claude-hook-*) dir="$HOME/.claude/hooks"; name=${name#claude-hook-} ;;
        git-hook-*)    dir="$HOME/.config/git/hooks"; name=${name#git-hook-} ;;
    esac
    mkdir -p "$dir"
    install -m 755 "$f" "$dir/$name"
done
[ -d "$HOME/.config/git/hooks" ] && git config --global core.hooksPath "$HOME/.config/git/hooks"
if [ -f "$CLAUDAINER_CONFIG/settings.json" ]; then
    settings="$HOME/.claude/settings.json"
    [ -s "$settings" ] || echo '{}' > "$settings"
    jq -s '.[0] * .[1]' "$settings" "$CLAUDAINER_CONFIG/settings.json" > "$settings.tmp" && mv "$settings.tmp" "$settings"
fi

# Nobody is there to answer the trust prompt.
state="$HOME/.claude.json"
[ -s "$state" ] || echo '{}' > "$state"
jq --arg ws "$WORKSPACE" '.projects[$ws].hasTrustDialogAccepted = true' "$state" > "$state.tmp" && mv "$state.tmp" "$state"

# Remote Control needs a full account login; setup-token / CLAUDE_CODE_OAUTH_TOKEN is inference-only.
if ! claude auth status >/dev/null 2>&1; then
    echo "claude: not logged in. Run: kubectl -n ${POD_NAMESPACE:-claude} exec -it ${HOSTNAME} -- claude auth login"
    echo "claude: waiting for credentials..."
    until claude auth status >/dev/null 2>&1; do sleep 10; done
fi

cd "$WORKSPACE"
exec claude remote-control \
    --remote-control-session-name-prefix "$SESSION_NAME_PREFIX" \
    --permission-mode "$PERMISSION_MODE" \
    --spawn "$SPAWN_MODE" \
    "$@"
