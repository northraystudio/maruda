#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) — deny destructive or policy-breaking commands.
# Exit 0 with no output = no opinion (normal permission flow applies).
# Always exits 0: unparseable input is "no opinion", never a hook error.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { cat >/dev/null; exit 0; }

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[[ -z "$cmd" ]] && exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# rm and git push are judged on their arguments, not by regex over the whole
# string: option spelling (-rf / -fr / -r -f / --recursive) must not matter,
# and a branch name that merely contains "main" must not match.
#
# Shell syntax is not fully parsed. Quotes are dropped and the command is cut
# into segments at ; | & < > and newlines (redirect targets never become
# arguments). It is cut twice, both conservative by design:
#   - inner: also at ( ) `, so commands nested in $(...) or bash -c "..." are
#     inspected on their own;
#   - outer: with each $(...) / `...` collapsed to $SUBST first, so the outer
#     command keeps its arguments — `git push -f "$(git remote)" main`.
SUBST='__MARUDA_SUBST__'

# $@ = arguments after rm. True when recursive + forced on a catastrophic target.
rm_is_catastrophic() {
  local recursive=0 force=0 opts=1 target=0 a
  for a in "$@"; do
    if ((opts)) && [[ "$a" == -- ]]; then opts=0; continue; fi
    if ((opts)) && [[ "$a" == --* ]]; then
      case "$a" in --recursive) recursive=1 ;; --force) force=1 ;; esac
      continue
    fi
    if ((opts)) && [[ "$a" == -?* ]]; then
      [[ "$a" == *[rR]* ]] && recursive=1
      [[ "$a" == *f* ]] && force=1
      continue
    fi
    case "$a" in
      / | '/*' | '~'* | '*'* | '$HOME'* | '${HOME}'*) target=1 ;;
    esac
  done
  ((recursive && force && target))
}

# $@ = arguments after push. True when forced (flag or +refspec) onto main/master,
# or onto a ref only known at run time (a command substitution after the remote).
push_forces_protected() {
  local forced=0 protected=0 opts=1 positional=0 a ref
  for a in "$@"; do
    if ((opts)) && [[ "$a" == -- ]]; then opts=0; continue; fi
    if ((opts)) && [[ "$a" == --* ]]; then
      case "$a" in --force | --force=* | --force-with-lease | --force-with-lease=*) forced=1 ;; esac
      continue
    fi
    if ((opts)) && [[ "$a" == -?* ]]; then
      [[ "$a" == *f* ]] && forced=1
      continue
    fi
    positional=$((positional + 1))
    ref="$a"
    [[ "$ref" == +* ]] && { forced=1; ref="${ref#+}"; }
    ref="${ref##*:}"
    ref="${ref#refs/heads/}"
    [[ "$ref" == main || "$ref" == master ]] && protected=1
    ((positional > 1)) && [[ "$ref" == *"$SUBST"* ]] && protected=1
  done
  ((forced && protected))
}

# $1 = command text. Replaces each innermost $(...) / `...` with $SUBST until none is left.
collapse_substitutions() {
  local s="$1" prev
  while :; do
    prev="$s"
    s=$(printf '%s\n' "$s" | sed -e "s/\\\$([^()]*)/$SUBST/g" -e "s/\`[^\`]*\`/$SUBST/g")
    [[ "$s" == "$prev" ]] && break
  done
  printf '%s\n' "$s"
}

# $1 = command text, $2 = extra separator characters. Denies on the first match.
inspect_segments() {
  local segment w i
  local -a words
  while IFS= read -r segment; do
    read -ra words <<<"$segment" || true
    for ((i = 0; i < ${#words[@]}; i++)); do
      w="${words[i]}"
      if [[ "$w" == rm || "$w" == */rm ]] && rm_is_catastrophic "${words[@]:i+1}"; then
        deny "Blocked by pre-bash-guard: recursive forced rm on /, ~, \$HOME or a bare glob. If this is intentional, ask the user to run it manually."
      fi
      if [[ "$w" == push ]] && ((i > 0)) && printf '%s\n' "${words[@]:0:i}" | grep -Eq '^(.*/)?git$' \
        && push_forces_protected "${words[@]:i+1}"; then
        deny "Blocked by pre-bash-guard: force push to main/master (or to a ref resolved at run time). If this is intentional, ask the user to run it manually."
      fi
    done
  done < <(printf '%s\n' "$1" | tr ";|&<>$2" '\n')
}

unquoted=$(printf '%s\n' "$cmd" | tr -d "\"'")
inspect_segments "$unquoted" '()`'
inspect_segments "$(collapse_substitutions "$unquoted")" ''

deny_patterns=(
  # Filesystem / system
  'mkfs\.'
  ':\(\)\{ *:\|:& *\};:'
  # Databases (irreversible, no WHERE-clause escape hatch)
  'DROP +DATABASE'
  'TRUNCATE +TABLE'
  # Infrastructure / production (irreversible or wide-blast-radius)
  'terraform +destroy'
  'kubectl +delete +namespace'
  'kubectl +delete +[^|;&]*--all'
  'docker +system +prune'
  'docker +volume +prune'
  'aws +s3 +rb'
  'aws +s3 +rm +[^|;&]*--recursive'
  'gcloud +projects +delete'
)

for p in "${deny_patterns[@]}"; do
  if echo "$cmd" | grep -Eiq "$p"; then
    deny "Blocked by pre-bash-guard: matched /$p/. If this is intentional, ask the user to run it manually."
  fi
done

# Block shell redirects into .env files (secret exfiltration / clobbering)
if echo "$cmd" | grep -Eq '(>|>>) *[^ ]*\.env([^a-zA-Z0-9_.-]|$)'; then
  deny "Refusing shell redirect into a .env file. Edit env files explicitly with user approval."
fi

# Optional: enforce uv over pip (enabled by setup when the project uses uv)
# GUARD_PIP_MARKER — do not remove; setup.sh toggles the block below.
if [[ "${DEV_SKILLS_GUARD_PIP:-0}" == "1" ]]; then
  if echo "$cmd" | grep -Eq '(^|[ ;|&])pip3? +install'; then
    deny "This project uses uv. Use 'uv add <pkg>' (or 'uv pip install' inside the venv) instead of pip install."
  fi
fi

exit 0
