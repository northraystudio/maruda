#!/usr/bin/env bash
# Stop hook — non-blocking nudge toward the continuous improvement cycle.
# Never blocks the stop: no "decision" field, always exit 0.
set -euo pipefail

cat >/dev/null # drain stdin
command -v jq >/dev/null 2>&1 || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    systemMessage: "[maruda] If code changed this session: consider /maruda:software-evaluation on the diff, or continue Plan → Resolve if an issue is in flight."
  }
}'
exit 0
