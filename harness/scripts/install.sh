#!/usr/bin/env bash
# maruda harness — one-liner entry point.
#
#   curl -fsSL https://raw.githubusercontent.com/ymd38/dev-skills/main/harness/scripts/install.sh \
#     | bash -s -- --langs go,typescript --pm pnpm
#
# Prefer inspecting before running:
#   curl -fsSL .../install.sh -o install.sh && less install.sh && bash install.sh --langs go
#
# This script only clones the repo to a temp dir and delegates to harness/scripts/setup.sh
# against the CURRENT directory. No sudo; writes only ./CLAUDE.md and ./.claude/.
set -euo pipefail

REPO="${DEV_SKILLS_REPO:-https://github.com/ymd38/dev-skills.git}"
REF="${DEV_SKILLS_REF:-main}"
TARGET="${DEV_SKILLS_TARGET:-$PWD}"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> fetching maruda ($REF)"
git clone --quiet --depth 1 --branch "$REF" "$REPO" "$TMP/maruda"

bash "$TMP/maruda/harness/scripts/setup.sh" --target "$TARGET" "$@"
