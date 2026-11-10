#!/bin/zsh
# Starts cc-connect for the agent. Secrets live in an env file outside the repo (chmod 600):
#   AGENT_APP_ID, AGENT_APP_SECRET   Lark app credentials
#   AGENT_ALLOW_FROM                 comma-separated open_ids allowed to talk to the agent
set -e
ENV_FILE="${AGENT_ENV_FILE:-$HOME/.config/mojo-lark-agent/env}"
set -a; source "$ENV_FILE"; set +a
unset CLAUDECODE   # a leftover CLAUDECODE var makes the claude CLI think it is nested
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${0:A:h}/.."
exec cc-connect --config "$PWD/config.toml"
