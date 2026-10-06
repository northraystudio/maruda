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
# Shell syntax is not fully parsed. Quotes are dropped, redirections (operator
# + operand) are removed without cutting the command — `push -f origin
# >/dev/null main` keeps main as an argument — and the command is cut into
# segments at ; | & and newlines. It is cut twice, both conservative by design:
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
    ((positional > 1)) && [[ "$ref" == *"$SUBST"* ]] && protected=1
    ref=$(printf '%s' "$ref" | tr 'A-Z' 'a-z') # case-insensitive filesystems
    [[ "$ref" == main || "$ref" == master ]] && protected=1
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

# $1 = command text. Removes each redirection (optional fd number, operator,
# operand) and leaves the surrounding arguments in place.
strip_redirections() {
  local op='(&>>|&>|>>|>[|]|>&|<<<|<<-|<<|<&|<>|>|<)'
  local operand='[[:space:]]*[^[:space:];|&<>()]*'
  printf '%s\n' "$1" | sed -E \
    -e "s/(^|[[:space:]])[0-9]+$op$operand/\\1 /g" \
    -e "s/$op$operand/ /g"
}

# $1 = command text, $2 = extra separator characters. Denies on the first match.
inspect_segments() {
  local segment w i
  local -a words
  while IFS= read -r segment; do
    # Split into words by plain assignment with globbing off. Not `read -ra
    # <<<`: a here-string needs a temp file, and when one cannot be created the
    # read fails, the parser sees nothing, and plain-word segments — exempt
    # from the legacy floor below — would slip through unjudged.
    set -f
    # shellcheck disable=SC2206 # word splitting is the point; globbing is off
    words=($segment)
    set +f
    for ((i = 0; i < ${#words[@]}; i++)); do
      w="${words[i]}"
      if [[ "$w" == rm || "$w" == */rm ]] && rm_is_catastrophic "${words[@]:i+1}"; then
        deny "Blocked by pre-bash-guard: recursive forced rm on /, ~, \$HOME or a bare glob. If this is intentional, ask the user to run it manually."
      fi
      if [[ "$w" == push ]] && ((i > 0)) && printf '%s\n' "${words[@]:0:i}" | grep -Eiq '^(.*/)?git$' \
        && push_forces_protected "${words[@]:i+1}"; then
        deny "Blocked by pre-bash-guard: force push to main/master (or to a ref resolved at run time). If this is intentional, ask the user to run it manually."
      fi
    done
  done < <(printf '%s\n' "$1" | tr ";|&$2" '\n')
}

unquoted=$(printf '%s\n' "$cmd" | tr -d "\"'")
inspect_segments "$(strip_redirections "$unquoted")" '()`'
# Parens left after collapsing are subshell/grouping boundaries, so cut there too.
inspect_segments "$(strip_redirections "$(collapse_substitutions "$unquoted")")" '()'

# Floor: never weaker than the previous regex-only guard. Shell syntax has more
# forms than the parser above models (brace expansion, separators inside
# quotes, --force-with-lease=<ref>, ...), so the old patterns stay in force:
#   - rm: always — they never produced false positives;
#   - force push: for every segment that is not plain words. Only a segment the
#     parser reads exactly may be allowed past the old pattern — that is what
#     fixes `git push --force origin feat/domain-model`.
legacy_rm_patterns=('rm -rf +/( |$)' 'rm -rf +~' 'rm -rf +\*')
for p in "${legacy_rm_patterns[@]}"; do
  if echo "$cmd" | grep -Eiq "$p"; then
    deny "Blocked by pre-bash-guard: matched /$p/. If this is intentional, ask the user to run it manually."
  fi
done

legacy_push_pattern='git push[^|;&]*(--force|-f)[^|;&]*(main|master)'
plain_words='^[A-Za-z0-9 ./_:+@-]*$'
while IFS= read -r segment; do
  [[ "$segment" =~ $plain_words ]] && continue
  if echo "$segment" | grep -Eiq "$legacy_push_pattern"; then
    deny "Blocked by pre-bash-guard: force push to main/master (the command is not plain words, so it is judged conservatively). If this is intentional, ask the user to run it manually."
  fi
done < <(printf '%s\n' "$cmd" | tr ';|&' '\n')

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
