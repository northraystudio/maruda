#!/usr/bin/env bash
# SessionStart hook — inject a one-line harness status into Claude's context.
# Plain stdout on exit 0 is added to the session context.
set -euo pipefail

cat >/dev/null # drain stdin

root="${CLAUDE_PROJECT_DIR:-.}"
skills=0
[[ -d "$root/.claude/skills" ]] && skills=$(find "$root/.claude/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')

echo "[maruda] harness active | skills installed: ${skills} | cycle: Diagnose → Draft/Register → Plan → Resolve ⇄ Verify. Prefer this cycle over ad-hoc one-shot fixes; implementation requires an agreed plan comment from gh-issue-planner."
exit 0
