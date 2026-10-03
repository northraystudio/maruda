#!/usr/bin/env bash
# PostToolUse hook (matcher: Write|Edit) — format the file that was just written.
# Always exits 0: formatting is best-effort and must never block the session.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { cat >/dev/null; exit 0; }

input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$file" || ! -f "$file" ]] && exit 0

# Installed skills belong to their installer (npx skills / skills-lock.json),
# not to this project's formatter.
case "$file" in
  .claude/skills/* | */.claude/skills/*) exit 0 ;;
esac

format_go() {
  if command -v goimports >/dev/null 2>&1; then
    goimports -w "$1" >/dev/null 2>&1 || gofmt -w "$1" >/dev/null 2>&1 || true
  else
    gofmt -w "$1" >/dev/null 2>&1 || true
  fi
}

format_py() {
  local root="${CLAUDE_PROJECT_DIR:-.}"
  if command -v uv >/dev/null 2>&1 && [[ -f "$root/uv.lock" || -f "$root/pyproject.toml" ]]; then
    uv run ruff format "$1" >/dev/null 2>&1 || true
  elif command -v ruff >/dev/null 2>&1; then
    ruff format "$1" >/dev/null 2>&1 || true
  elif command -v black >/dev/null 2>&1; then
    black -q "$1" >/dev/null 2>&1 || true
  fi
}

format_js_ts() {
  # Only run a locally-installed, lockfile-pinned Prettier. Never fall back to
  # `npx --yes`: that downloads and executes unpinned registry code on every edit.
  local root="${CLAUDE_PROJECT_DIR:-.}"
  if [[ -x "$root/node_modules/.bin/prettier" ]]; then
    "$root/node_modules/.bin/prettier" --write "$1" >/dev/null 2>&1 || true
  elif command -v prettier >/dev/null 2>&1; then
    prettier --write "$1" >/dev/null 2>&1 || true
  fi
}

case "$file" in
  *.go)  format_go "$file" ;;
  *.py)  format_py "$file" ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md)
         format_js_ts "$file" ;;
esac
exit 0
