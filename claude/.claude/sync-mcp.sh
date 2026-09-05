#!/usr/bin/env bash
#
# Apply ~/.claude/mcp.json to Claude Code's user-scope MCP config.
#
# Claude Code only reads user-scope MCP servers from ~/.claude.json, which also
# holds session/runtime state and so is not tracked in dotfiles. mcp.json is the
# tracked source of truth; this script replays it. Idempotent — safe to re-run.
#
# Secrets are never stored here: values use ${VAR} placeholders that Claude Code
# expands from the environment (direnv supplies them, see CLAUDE.md).

set -euo pipefail

source_file="${1:-$HOME/.claude/mcp.json}"

if [[ ! -f "$source_file" ]]; then
  printf '[sync-mcp] no such file: %s\n' "$source_file" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  printf '[sync-mcp] claude not on PATH; skipping\n' >&2
  exit 0
fi

while IFS= read -r name; do
  config=$(jq -c --arg n "$name" '.mcpServers[$n]' "$source_file")
  claude mcp remove -s user "$name" >/dev/null 2>&1 || true
  claude mcp add-json -s user "$name" "$config" >/dev/null
  printf '[sync-mcp] %s\n' "$name"
done < <(jq -r '.mcpServers | keys[]' "$source_file")
