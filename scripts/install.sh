#!/bin/zsh
# Renders the templates into an agent folder and (optionally) installs the macOS LaunchAgent.
#
#   AGENT_DIR=~/agents/ada AGENT_NAME=Ada OWNER_NAME=Sam \
#   OWNER_OPEN_ID=ou_xxx WORKSPACE_DIR=~/work ./scripts/install.sh [--launchd]
#
# Optional: AGENT_SLUG (default: lowercased AGENT_NAME), LANGUAGE (zh|en, default zh),
# PLATFORM (lark|feishu, default lark), PERMISSION_MODE (default|bypassPermissions, default default),
# MODEL (default claude-opus-5-5), EFFORT (low|medium|high, default medium).
set -euo pipefail
ROOT="${0:A:h}/.."

: "${AGENT_DIR:?set AGENT_DIR}" "${AGENT_NAME:?set AGENT_NAME}" "${OWNER_NAME:?set OWNER_NAME}"
: "${OWNER_OPEN_ID:?set OWNER_OPEN_ID (send /whoami to the bot once cc-connect runs)}"
: "${WORKSPACE_DIR:?set WORKSPACE_DIR}"
export AGENT_DIR="${AGENT_DIR:A}" WORKSPACE_DIR="${WORKSPACE_DIR:A}"
export AGENT_NAME OWNER_NAME OWNER_OPEN_ID
export AGENT_SLUG="${AGENT_SLUG:-${(L)AGENT_NAME}}"
export LANGUAGE="${LANGUAGE:-zh}" PLATFORM="${PLATFORM:-lark}"
export PERMISSION_MODE="${PERMISSION_MODE:-default}" MODEL="${MODEL:-claude-opus-5-5}" EFFORT="${EFFORT:-medium}"
if [[ "$PLATFORM" == feishu ]]; then export LARK_DOMAIN="https://open.feishu.cn"; else export LARK_DOMAIN="https://open.larksuite.com"; fi
export DATA_DIR="$HOME/.cc-connect/$AGENT_SLUG" LAUNCHD_LABEL="com.mojo-lark-agent.$AGENT_SLUG"
export NODE_BIN="$(command -v node || true)" HOME

mkdir -p "$AGENT_DIR/.claude" "$AGENT_DIR/scripts" "$AGENT_DIR/groups" "$AGENT_DIR/launchd"

render() {  # render <template> <dest>: replace {{VAR}} with env values
  python3 -I - "$1" "$2" <<'PY'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
def sub(m):
    v = os.environ.get(m.group(1))
    if v is None: sys.exit(f"missing variable {m.group(1)} for {src}")
    return v
open(dst, "w").write(re.sub(r"\{\{([A-Z_]+)\}\}", sub, text))
PY
}

for f in config.toml CLAUDE.md; do
  [[ -e "$AGENT_DIR/$f" ]] && { echo "keep existing $AGENT_DIR/$f"; continue; }
  render "$ROOT/templates/$f" "$AGENT_DIR/$f"
done
[[ -e "$AGENT_DIR/.claude/settings.json" ]] || render "$ROOT/templates/.claude/settings.json" "$AGENT_DIR/.claude/settings.json"
cp "$ROOT/scripts/run.sh" "$ROOT/scripts/launch.mjs" "$AGENT_DIR/scripts/" && chmod +x "$AGENT_DIR/scripts/run.sh"
printf 'groups/*.md\n.config.toml.lock\n*.log\n' > "$AGENT_DIR/.gitignore"

# Claude Code ignores a project's permissions.allow and additionalDirectories until the folder is
# trusted. Mark the agent folder trusted in ~/.claude.json (backup first).
if [[ -f "$HOME/.claude.json" ]] && command -v jq >/dev/null; then
  cp "$HOME/.claude.json" "$HOME/.claude.json.bak-mojo-lark-agent"
  jq --arg d "$AGENT_DIR" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' \
    "$HOME/.claude.json" > "$HOME/.claude.json.tmp" && mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
  echo "trusted $AGENT_DIR in ~/.claude.json"
else
  echo "WARN: run 'claude' once in $AGENT_DIR and accept the trust dialog"
fi

ENV_FILE="$HOME/.config/mojo-lark-agent/env"
if [[ ! -f "$ENV_FILE" ]]; then
  mkdir -p "${ENV_FILE:h}" && chmod 700 "${ENV_FILE:h}"
  printf 'AGENT_APP_ID=\nAGENT_APP_SECRET=\nAGENT_ALLOW_FROM=%s\n' "$OWNER_OPEN_ID" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "fill in $ENV_FILE (app id / secret)"
fi

if [[ "${1:-}" == --launchd ]]; then
  [[ -n "$NODE_BIN" ]] || { echo "node not found"; exit 1; }
  render "$ROOT/launchd/agent.plist.template" "$AGENT_DIR/launchd/$LAUNCHD_LABEL.plist"
  cp "$AGENT_DIR/launchd/$LAUNCHD_LABEL.plist" "$HOME/Library/LaunchAgents/"
  launchctl bootout "gui/$(id -u)/$LAUNCHD_LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist"
  echo "LaunchAgent $LAUNCHD_LABEL started; log: ~/Library/Logs/$AGENT_SLUG.log"
fi
echo "done: $AGENT_DIR"
