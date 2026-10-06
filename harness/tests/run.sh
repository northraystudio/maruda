#!/usr/bin/env bash
# Automated checks for the harness installer and hook templates.
# Usage: bash harness/tests/run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SETUP="$ROOT/harness/scripts/setup.sh"
HOOKS="$ROOT/harness/templates/hooks"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { # $1 description, $2 command (eval'd)
  if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi
}

# ── 1. Full generation (go+ts, pnpm) ─────────
mkdir -p "$WORK/full"
bash "$SETUP" --target "$WORK/full" --langs go,typescript --pm pnpm >"$WORK/full.out" 2>&1
for f in CLAUDE.md .claude/settings.json .claude/hooks/post-write-format.sh \
         .claude/hooks/pre-bash-guard.sh .claude/rules/maruda-cycle.md \
         .github/workflows/ci.yml .github/workflows/security-scan.yml \
         .gitleaks.toml .semgrepignore .gitignore .env.example; do
  check "full: $f exists" "[[ -f '$WORK/full/$f' ]]"
done
check "full: ci.yml has push trigger"            "grep -q 'push:' '$WORK/full/.github/workflows/ci.yml'"
check "full: ci.yml is strict (no --if-present)" "! grep -q -- '--if-present' '$WORK/full/.github/workflows/ci.yml'"
check "full: only trivy is continue-on-error"    "[[ \$(grep -c 'continue-on-error: true' '$WORK/full/.github/workflows/security-scan.yml') -eq 1 ]]"
check "full: scan has push trigger"              "grep -q 'push:' '$WORK/full/.github/workflows/security-scan.yml'"
check "full: format hook never invokes npx"      "! grep -Eq '^[^#]*\bnpx\b' '$WORK/full/.claude/hooks/post-write-format.sh'"
check "full: checklist reports protection state" "grep -q 'protection:' '$WORK/full.out'"
check "full: node preflight validates scripts"   "grep -q 'Validate required package scripts' '$WORK/full/.github/workflows/ci.yml'"
check "full: go.mod guard before setup-go"       "grep -q 'Check go.mod exists' '$WORK/full/.github/workflows/ci.yml'"
check "full: golangci-lint cache pinned by SHA"  "grep -q 'actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830' '$WORK/full/.github/workflows/ci.yml'"
check "full: TS job has Typecheck step"          "grep -q 'name: Typecheck' '$WORK/full/.github/workflows/ci.yml'"
check "full: harness-checklist.md written"       "[[ -f '$WORK/full/docs/harness-checklist.md' ]]"
check "full: coding principles installed"        "[[ -f '$WORK/full/.claude/rules/coding-principles.md' ]]"
check "full: go + ts rules installed"            "[[ -f '$WORK/full/.claude/rules/go.md' && -f '$WORK/full/.claude/rules/typescript.md' ]]"

# ── Language-variant CI jobs ─────────────────
mkdir -p "$WORK/jsonly" "$WORK/pyonly"
bash "$SETUP" --target "$WORK/jsonly" --langs javascript --pm npm >/dev/null 2>&1
check "js-only: no Typecheck step"               "! grep -q 'name: Typecheck' '$WORK/jsonly/.github/workflows/ci.yml'"
check "js-only: required list lacks typecheck"   "! grep -q \"'typecheck'\" '$WORK/jsonly/.github/workflows/ci.yml'"
bash "$SETUP" --target "$WORK/pyonly" --langs python >/dev/null 2>&1
check "python: pytest exit-5 annotated"          "grep -q 'No tests collected' '$WORK/pyonly/.github/workflows/ci.yml'"
check "python: python rules installed"           "[[ -f '$WORK/pyonly/.claude/rules/python.md' ]]"
check "python: no go rules"                      "[[ ! -f '$WORK/pyonly/.claude/rules/go.md' ]]"
check "python: no node audit job"                "! grep -q 'dep-audit-node' '$WORK/pyonly/.github/workflows/security-scan.yml'"
check "python: all CI files written (no abort)"  "[[ -f '$WORK/pyonly/.gitleaks.toml' && -f '$WORK/pyonly/.semgrepignore' ]]"
mkdir -p "$WORK/bunts"
check "bun: setup exits 0 without audit job"     "bash '$SETUP' --target '$WORK/bunts' --langs typescript --pm bun"
if python3 -c 'import yaml' >/dev/null 2>&1; then
  check "yaml: js-only ci.yml parses" "python3 -c \"import yaml; yaml.safe_load(open('$WORK/jsonly/.github/workflows/ci.yml'))\""
  check "yaml: py-only ci.yml parses" "python3 -c \"import yaml; yaml.safe_load(open('$WORK/pyonly/.github/workflows/ci.yml'))\""
fi

# ── Flow: integration branch & PR bases ─────
FULL_CI="$WORK/full/.github/workflows/ci.yml"
FULL_SCAN="$WORK/full/.github/workflows/security-scan.yml"
check "flow: PR base includes default branch"    "grep -qx '      - main' '$FULL_CI'"
for base in 'epic/**' 'feat/**' 'fix/**' 'refactor/**'; do
  check "flow: PR base includes $base"           "grep -qxF \"      - '$base'\" '$FULL_CI'"
done
# epic/** must appear in the pull_request filter only — pushes stay narrow.
check "flow: push trigger stays narrow (ci)"     "[[ \$(grep -cF \"epic/**\" '$FULL_CI') -eq 1 ]]"
check "flow: scan PR base includes epic"         "grep -qxF \"      - 'epic/**'\" '$FULL_SCAN'"
check "flow: push trigger stays narrow (scan)"   "[[ \$(grep -cF \"epic/**\" '$FULL_SCAN') -eq 1 ]]"
check "flow: default is individual in CLAUDE.md" "grep -q 'Default flow for several Issues at once: \`individual\`' '$WORK/full/CLAUDE.md'"
check "flow: default integration = --branch"     "grep -q 'PR integration branch: \`main\`' '$WORK/full/CLAUDE.md'"
check "flow: checklist reports flow"             "grep -q 'flow:.*integration branch: main | default: individual' '$WORK/full.out'"
check "flow: no unreplaced tokens in CLAUDE.md"  "! grep -Eq '\{\{[A-Z_]+\}\}' '$WORK/full/CLAUDE.md'"
check "flow: no unreplaced tokens in ci.yml"     "! grep -Eq '\{\{[A-Z_]+\}\}' '$FULL_CI'"

mkdir -p "$WORK/flow"
bash "$SETUP" --target "$WORK/flow" --langs go --integration-branch staging \
  --default-flow batch --pr-agent >"$WORK/flow.out" 2>&1
FLOW_CI="$WORK/flow/.github/workflows/ci.yml"
check "staging: recorded in CLAUDE.md"           "grep -q 'PR integration branch: \`staging\`' '$WORK/flow/CLAUDE.md'"
check "staging: default flow recorded"           "grep -q 'Default flow for several Issues at once: \`batch\`' '$WORK/flow/CLAUDE.md'"
check "staging: both branches are PR bases"      "grep -qx '      - main' '$FLOW_CI' && grep -qx '      - staging' '$FLOW_CI'"
# staging appears once in the pull_request filter and once in the push filter.
check "staging: push trigger covers staging"     "[[ \$(grep -cx '      - staging' '$FLOW_CI') -eq 2 ]]"
check "staging: pr-agent picks up staging"       "grep -qx '      - staging' '$WORK/flow/.github/workflows/pr-agent.yml'"
check "staging: checklist reports it"            "grep -q 'flow:.*integration branch: staging | default: batch' '$WORK/flow.out'"
check "flow: invalid --default-flow fails"       "! bash '$SETUP' --target '$WORK/flow' --langs go --default-flow bogus"
if python3 -c 'import yaml' >/dev/null 2>&1; then
  for y in ci.yml security-scan.yml pr-agent.yml; do
    check "yaml: staging $y parses" "python3 -c \"import yaml; yaml.safe_load(open('$WORK/flow/.github/workflows/$y'))\""
  done
fi

# ── 2. YAML validity (needs python3 + pyyaml) ─
if python3 -c 'import yaml' >/dev/null 2>&1; then
  for y in ci.yml security-scan.yml; do
    check "yaml: $y parses" "python3 -c \"import yaml; yaml.safe_load(open('$WORK/full/.github/workflows/$y'))\""
  done
else
  echo "SKIP  yaml validation (python3/pyyaml unavailable)"
fi

# ── 3. Idempotent re-run keeps files ─────────
bash "$SETUP" --target "$WORK/full" --langs go,typescript --pm pnpm >"$WORK/rerun.out" 2>&1
check "rerun: hooks kept"      "grep -q 'installed=0 kept=4' '$WORK/rerun.out'"
check "rerun: CI kept"         "grep -q 'written=0 kept=4' '$WORK/rerun.out'"
check "rerun: CLAUDE.md up to date" "grep -q 'CLAUDE.md:  up to date' '$WORK/rerun.out'"
check "rerun: no proposals on identical content" "grep -q 'updates:    none' '$WORK/rerun.out'"

# ── 4. --minimal ─────────────────────────────
mkdir -p "$WORK/min"
bash "$SETUP" --target "$WORK/min" --minimal >/dev/null 2>&1
check "minimal: no CLAUDE.md"  "[[ ! -f '$WORK/min/CLAUDE.md' ]]"
check "minimal: no .github"    "[[ ! -d '$WORK/min/.github' ]]"
check "minimal: hooks present" "[[ -f '$WORK/min/.claude/hooks/pre-bash-guard.sh' ]]"
check "minimal: principles yes, lang rules no" "[[ -f '$WORK/min/.claude/rules/coding-principles.md' && ! -f '$WORK/min/.claude/rules/go.md' ]]"

# ── 5. Component opt-outs ────────────────────
mkdir -p "$WORK/optout"
bash "$SETUP" --target "$WORK/optout" --langs go --no-ci --no-rules --no-env-guard --no-format-hook >/dev/null 2>&1
check "optout: no rules"        "[[ ! -f '$WORK/optout/.claude/rules/maruda-cycle.md' ]]"
check "optout: no .env.example" "[[ ! -f '$WORK/optout/.env.example' ]]"
check "optout: no format hook"  "[[ ! -f '$WORK/optout/.claude/hooks/post-write-format.sh' ]]"
check "optout: no .github"      "[[ ! -d '$WORK/optout/.github' ]]"
if command -v jq >/dev/null 2>&1; then
  check "optout: settings drops format hook entry" \
    "! jq -e '.hooks.PostToolUse' '$WORK/optout/.claude/settings.json'"
  check "optout: settings keeps bash guard entry" \
    "jq -e '.hooks.PreToolUse' '$WORK/optout/.claude/settings.json'"
fi

# ── 6. settings.json merge preserves user hooks ──
mkdir -p "$WORK/merge/.claude"
printf '{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo user-hook"}]}]}}\n' \
  >"$WORK/merge/.claude/settings.json"
bash "$SETUP" --target "$WORK/merge" --langs go --no-ci >/dev/null 2>&1
if command -v jq >/dev/null 2>&1; then
  check "merge: user hook preserved"   "jq -e '.hooks.PreToolUse[].hooks[].command | select(. == \"echo user-hook\")' '$WORK/merge/.claude/settings.json'"
  check "merge: permissions preserved" "jq -e '.permissions.allow[0] == \"Bash(ls:*)\"' '$WORK/merge/.claude/settings.json'"
fi

# ── 7. .env guard appends without clobbering ─
mkdir -p "$WORK/env"
printf 'node_modules/\n.env\n' >"$WORK/env/.gitignore"
bash "$SETUP" --target "$WORK/env" --minimal >/dev/null 2>&1
check "env: original line kept"   "grep -qxF 'node_modules/' '$WORK/env/.gitignore'"
check "env: .env not duplicated"  "[[ \$(grep -cxF '.env' '$WORK/env/.gitignore') -eq 1 ]]"
check "env: negation appended"    "grep -qxF '!.env.example' '$WORK/env/.gitignore'"

# ── 8. Bash guard deny/allow matrix ──────────
guard() { # $1 command string → prints decision or "allowed"
  local out
  out=$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)" | bash "$HOOKS/pre-bash-guard.sh")
  local d
  d=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allowed"' 2>/dev/null)
  echo "${d:-allowed}"
}
if command -v jq >/dev/null 2>&1; then
  while IFS='|' read -r expect cmd; do
    if [[ "$(guard "$cmd")" == "$expect" ]]; then ok "guard: $expect '$cmd'"; else bad "guard: expected $expect for '$cmd'"; fi
  done <<'CASES'
deny|rm -rf /
deny|rm -fr /
deny|rm -r -f /
deny|rm -rf -- /
deny|rm --recursive --force /
deny|rm -Rf /*
deny|rm -fr ~
deny|rm -rf ~/projects
deny|rm -rf $HOME
deny|rm -rf *
deny|sudo rm -rf /
deny|cd /tmp && rm -fr /
deny|bash -c "rm -fr /"
deny|echo $(rm -rf ~)
deny|git push -f origin main
deny|git push origin +main
deny|git push --force origin refs/heads/main
deny|git push --force-with-lease origin HEAD:main
deny|git -C repo push -uf origin master
deny|git push --force origin main>/dev/null
deny|git push --force origin main 2>&1
deny|git push --force "$(git remote)" main
deny|git push --force `git remote` main
deny|git push --force origin $(git branch --show-current)
deny|git push --force origin HEAD:`git branch --show-current`
deny|(git push --force "$(git remote)" main)
deny|(cd x && git push --force `git remote` HEAD:main 2>&1)
deny|git push --force origin {main,develop}
deny|git push --force origin {develop,main}
deny|git push --force "https://host/x(y).git" main
deny|git push --force-with-lease=main:abc123 origin
deny|git push --force-with-lease=main origin
deny|git push --force-with-lease=refs/heads/main:abc origin
deny|GIT push -f origin MAIN
deny|git push --force origin feat/x >main.log
deny|git push --force origin >/dev/null main
deny|git push --force origin 2>/dev/null main
deny|git push --force origin &>/dev/null main
deny|git push --force >/dev/null origin main
deny|git push --force origin 2>&1 main
deny|git push --force origin < /dev/null main
deny|rm -rf />/dev/null
deny|rm -rf >/dev/null /
deny|rm -rf 2>&1 /
deny|rm -rf 2> /dev/null ~
deny|rm -rf $(echo x) /
deny|(cd /tmp; rm -rf /)
deny|terraform destroy
deny|docker system prune -af
deny|echo x >> .env
allowed|terraform plan
allowed|rm -rf node_modules
allowed|rm -rf ./build
allowed|rm -f /tmp/x.log
allowed|rm -r ~/scratch-no-force
allowed|git push origin feature/x
allowed|git push origin main
allowed|git push --force origin feat/domain-model
allowed|git push --force-with-lease origin feat/maintenance-fix
allowed|git push origin +feat/x
allowed|git push --force "$(git remote)" feat/x
allowed|git push origin $(git branch --show-current)
allowed|git push --force origin feat/x >/dev/null 2>&1
allowed|rm -rf $(mktemp -d)
allowed|git push --force-with-lease=feat/x:abc123 origin
allowed|git push --follow-tags origin main
allowed|rm -rf build >/dev/null 2>&1
allowed|kubectl delete pod my-pod
CASES
fi

# ── 8b. Hooks never fail on unparseable input; Stop output shape ──
if command -v jq >/dev/null 2>&1; then
  for h in pre-bash-guard.sh post-write-format.sh; do
    check "broken input: $h exits 0" "echo 'not json' | bash '$HOOKS/$h'"
  done
  # The guard must not depend on temp files: with file writes failing
  # (ulimit -f 0 breaks here-strings/heredocs), denials must still hold.
  guard_no_tmpfile() {
    printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)" \
      | bash -c 'trap "" XFSZ; ulimit -f 0; exec bash "$1"' _ "$HOOKS/pre-bash-guard.sh" 2>/dev/null \
      | jq -r '.hookSpecificOutput.permissionDecision // "allowed"' 2>/dev/null
  }
  for c in 'git push -f origin main' 'rm -fr /'; do
    if [[ "$(guard_no_tmpfile "$c")" == deny ]]; then ok "no temp file: deny '$c'"; else bad "no temp file: expected deny for '$c'"; fi
  done
  check "stop: systemMessage at top level" \
    "echo '{}' | bash '$HOOKS/stop-suggest-cycle.sh' | jq -e '(.systemMessage | type == \"string\") and (has(\"hookSpecificOutput\") | not)'"
fi

# ── 8c. Format hook leaves installed skills alone ──
mkdir -p "$WORK/fmt/bin" "$WORK/fmt/proj/.claude/skills/x"
printf '#!/usr/bin/env bash\necho formatted >>"%s/fmt/calls"\n' "$WORK" >"$WORK/fmt/bin/prettier"
chmod +x "$WORK/fmt/bin/prettier"
printf '# x\n' >"$WORK/fmt/proj/.claude/skills/x/SKILL.md"
printf '# y\n' >"$WORK/fmt/proj/README.md"
fmt() { jq -n --arg f "$1" '{tool_input:{file_path:$f}}' | PATH="$WORK/fmt/bin:$PATH" CLAUDE_PROJECT_DIR="$WORK/fmt/proj" bash "$HOOKS/post-write-format.sh"; }
if command -v jq >/dev/null 2>&1; then
  fmt "$WORK/fmt/proj/.claude/skills/x/SKILL.md"
  check "format: installed SKILL.md skipped" "[[ ! -f '$WORK/fmt/calls' ]]"
  fmt "$WORK/fmt/proj/README.md"
  check "format: project markdown still formatted" "[[ -f '$WORK/fmt/calls' ]]"
fi

# ── 8.5 Drift → *.new proposals; --force clears them ──
echo "# local tweak" >>"$WORK/full/.claude/hooks/pre-bash-guard.sh"
printf '# custom header\n' | cat - "$WORK/full/.github/workflows/ci.yml" >"$WORK/full/.github/workflows/ci.yml.tmp"
mv "$WORK/full/.github/workflows/ci.yml.tmp" "$WORK/full/.github/workflows/ci.yml"
bash "$SETUP" --target "$WORK/full" --langs go,typescript --pm pnpm >"$WORK/drift.out" 2>&1
check "drift: hook proposal written"     "[[ -f '$WORK/full/.claude/hooks/pre-bash-guard.sh.new' ]]"
check "drift: hook proposal executable"  "[[ -x '$WORK/full/.claude/hooks/pre-bash-guard.sh.new' ]]"
check "drift: original hook untouched"   "grep -q 'local tweak' '$WORK/full/.claude/hooks/pre-bash-guard.sh'"
check "drift: ci proposal written"       "[[ -f '$WORK/full/.github/workflows/ci.yml.new' ]]"
check "drift: original ci untouched"     "grep -q 'custom header' '$WORK/full/.github/workflows/ci.yml'"
check "drift: proposals listed in output" "grep -q 'proposed update files:' '$WORK/drift.out'"
bash "$SETUP" --target "$WORK/full" --langs go,typescript --pm pnpm --force >/dev/null 2>&1
check "force: overwrites drifted files"  "! grep -q 'local tweak' '$WORK/full/.claude/hooks/pre-bash-guard.sh'"
check "force: clears stale .new files"   "[[ ! -f '$WORK/full/.claude/hooks/pre-bash-guard.sh.new' && ! -f '$WORK/full/.github/workflows/ci.yml.new' ]]"

# ── 8.7 PR Agent (opt-in, advisory) ──────────
PA="$WORK/pragent"; mkdir -p "$PA"
PAW="$PA/.github/workflows/pr-agent.yml"
check "pr-agent: absent by default"            "[[ ! -f '$WORK/full/.github/workflows/pr-agent.yml' && ! -f '$WORK/full/.pr_agent.toml' ]]"
check "pr-agent: --minimal --pr-agent fails"   "! bash '$SETUP' --target '$PA' --minimal --pr-agent >/dev/null 2>&1"
bash "$SETUP" --target "$PA" --langs go --pr-agent >"$WORK/pragent.out" 2>&1
check "pr-agent: workflow + toml written"      "[[ -f '$PAW' && -f '$PA/.pr_agent.toml' ]]"
check "pr-agent: own status row, secret named" "grep -q 'pr-agent:   written=2 kept=0 proposed=0.*OPENAI_KEY' '$WORK/pragent.out'"
check "pr-agent: CI count stays 4"             "grep -q 'written=4 kept=0 proposed=0 (ci.yml' '$WORK/pragent.out'"
check "pr-agent: action pinned to tag SHA"     "grep -Eq 'uses: qodo-ai/pr-agent@[0-9a-f]{40} # v[0-9.]+' '$PAW'"
check "pr-agent: pull_request, never _target"  "grep -q '^  pull_request:' '$PAW' && ! grep -q 'pull_request_target' '$PAW'"
check "pr-agent: no workflow_run gate"         "! grep -q 'workflow_run' '$PAW'"
check "pr-agent: branch filter rendered"       "grep -qx '      - main' '$PAW' && grep -qxF \"      - 'epic/**'\" '$PAW'"
check "pr-agent: draft + fork guards"          "grep -q 'pull_request.draft == false' '$PAW' && grep -q 'head.repo.full_name == github.repository' '$PAW'"
check "pr-agent: slash cmd allowlist + prefix" "grep -q 'startsWith(github.event.comment.body' '$PAW' && grep -q '\"OWNER\",\"MEMBER\",\"COLLABORATOR\"' '$PAW'"
check "pr-agent: concurrency split by event"   "grep -q 'group: pr-agent-.*github.event_name' '$PAW' && grep -q 'cancel-in-progress: .*github.event_name == ' '$PAW'"
check "pr-agent: least-privilege permissions"  "grep -q '^  contents: read' '$PAW' && ! grep -q 'contents: write' '$PAW' && grep -q 'pull-requests: write' '$PAW'"
check "pr-agent: both jobs have timeouts"      "[[ \$(grep -c 'timeout-minutes:' '$PAW') -eq 2 ]]"
check "pr-agent: model lives in toml only"     "grep -q '^model = \"gpt-5.3-codex\"' '$PA/.pr_agent.toml' && ! grep -q 'config.model' '$PAW' && ! grep -q '^custom_model_max_tokens' '$PA/.pr_agent.toml'"
check "pr-agent: pushes re-run /review only"   "grep -q '^handle_push_trigger = true' '$PA/.pr_agent.toml' && grep -q '^push_commands = \[\"/review\"\]' '$PA/.pr_agent.toml' && ! grep -q 'pr_actions = .*synchronize' '$PA/.pr_agent.toml'"
check "pr-agent: checklist has secret step"    "grep -q 'OPENAI_KEY' '$PA/docs/harness-checklist.md'"
if python3 -c 'import yaml' >/dev/null 2>&1; then
  check "yaml: pr-agent.yml parses" "python3 -c \"import yaml; yaml.safe_load(open('$PAW'))\""
fi
if python3 -c 'import tomllib' >/dev/null 2>&1; then
  check "toml: .pr_agent.toml parses" "python3 -c \"import tomllib; tomllib.load(open('$PA/.pr_agent.toml','rb'))\""
fi
bash "$SETUP" --target "$PA" --langs go --pr-agent >"$WORK/pragent-rerun.out" 2>&1
check "pr-agent: rerun keeps both"             "grep -q 'pr-agent:   written=0 kept=2 proposed=0' '$WORK/pragent-rerun.out'"
echo "# local tweak" >>"$PA/.pr_agent.toml"
bash "$SETUP" --target "$PA" --langs go --pr-agent >"$WORK/pragent-drift.out" 2>&1
check "pr-agent: drift proposes .new"          "[[ -f '$PA/.pr_agent.toml.new' ]] && grep -q 'pr-agent:   written=0 kept=1 proposed=1' '$WORK/pragent-drift.out'"
PANC="$WORK/pragent-noci"; mkdir -p "$PANC"
bash "$SETUP" --target "$PANC" --langs go --no-ci --pr-agent >/dev/null 2>&1
check "pr-agent: composes with --no-ci"        "[[ -f '$PANC/.github/workflows/pr-agent.yml' && ! -f '$PANC/.github/workflows/ci.yml' ]]"
check "pr-agent: --no-ci checklist is PA-only" "grep -q 'OPENAI_KEY' '$PANC/docs/harness-checklist.md' && ! grep -q 'trivy' '$PANC/docs/harness-checklist.md'"
printf '# mine\n' >"$PANC/docs/harness-checklist.md"
bash "$SETUP" --target "$PANC" --langs go --no-ci --pr-agent >/dev/null 2>&1
check "pr-agent: existing checklist appended"  "grep -q '^# mine' '$PANC/docs/harness-checklist.md' && grep -q 'OPENAI_KEY' '$PANC/docs/harness-checklist.md'"
# --protect must never require the advisory job: a fake gh captures the payload.
PAP="$WORK/pragent-protect"; mkdir -p "$PAP/bin" "$PAP/target"
cat >"$PAP/bin/gh" <<'GH'
#!/usr/bin/env bash
# fake gh for tests: answers repo view, records the branch-protection PUT payload
case "$*" in
  "repo view --json nameWithOwner -q .nameWithOwner") echo "acme/demo" ;;
  "api -X PUT "*" --input "*) cp "${@: -1}" "$FAKE_GH_PAYLOAD" ;;
  *) exit 0 ;;
esac
GH
chmod +x "$PAP/bin/gh"
(cd "$PAP/target" && git init -q && git remote add origin https://example.invalid/acme/demo.git)
FAKE_GH_PAYLOAD="$PAP/payload.json" PATH="$PAP/bin:$PATH" \
  bash "$SETUP" --target "$PAP/target" --langs go --pr-agent --protect >"$WORK/pragent-protect.out" 2>&1
check "pr-agent: --protect payload captured"   "[[ -s '$PAP/payload.json' ]] && grep -q 'protection: applied' '$WORK/pragent-protect.out'"
check "pr-agent: never a required check"       "! grep -q 'PR Agent' '$PAP/payload.json' && grep -q 'SAST (Semgrep)' '$PAP/payload.json'"

# ── Supply chain: every action is SHA-pinned ──
# A tag can be repointed at any commit, so a tag reference does not pin
# anything. Run last, so every target generated above is covered.
unpinned_uses() { # $1: a .github/workflows directory → prints the unpinned count
  grep -rhE '\buses: ' "$1" 2>/dev/null | grep -cvE 'uses: [^@[:space:]]+@[0-9a-f]{40} # v[0-9]' || true
}
for t in full jsonly pyonly bunts flow; do
  wf="$WORK/$t/.github/workflows"
  [[ -d "$wf" ]] || continue
  check "pin: $t workflows are SHA-pinned" "[[ \$(unpinned_uses '$wf') -eq 0 ]]"
done
check "pin: pr-agent target is SHA-pinned"  "[[ \$(unpinned_uses '$PA/.github/workflows') -eq 0 ]]"
# Guard the guard: unpinned_uses must actually count an unpinned line,
# otherwise the checks above would pass on an empty or broken match.
mkdir -p "$WORK/pinprobe"
printf 'jobs:\n  a:\n    steps:\n      - uses: actions/checkout@v4\n' >"$WORK/pinprobe/probe.yml"
check "pin: detector counts a mutable tag" "[[ \$(unpinned_uses '$WORK/pinprobe') -eq 1 ]]"

# ── 10. --plugin registers the marketplace ───
# Claude Code does not auto-install from settings, so the flag's whole job is
# writing two keys without disturbing anything already in settings.json.
if command -v jq >/dev/null 2>&1; then
  PL="$WORK/plugin"
  mkdir -p "$PL"
  bash "$SETUP" --target "$PL" --langs go --no-ci --plugin >"$WORK/plugin.out" 2>&1
  PLS="$PL/.claude/settings.json"
  check "plugin: marketplace registered" \
    "jq -e '.extraKnownMarketplaces.northraystudio.source.repo == \"northraystudio/maruda\"' '$PLS'"
  check "plugin: ref defaults to main" \
    "jq -e '.extraKnownMarketplaces.northraystudio.source.ref == \"main\"' '$PLS'"
  check "plugin: plugin enabled" \
    "jq -e '.enabledPlugins[\"maruda@northraystudio\"] == true' '$PLS'"
  check "plugin: hooks still written" "jq -e '.hooks.PreToolUse' '$PLS'"
  check "plugin: checklist reports it" "grep -q 'plugin:     registered' '$WORK/plugin.out'"
  check "plugin: next step is /plugin install" \
    "grep -q '/plugin install maruda@northraystudio' '$WORK/plugin.out'"

  # --plugin-ref pins a tag; marketplace sources cannot take a SHA.
  PLR="$WORK/pluginref"
  mkdir -p "$PLR"
  bash "$SETUP" --target "$PLR" --minimal --plugin --plugin-ref v0.1.0 >/dev/null 2>&1
  check "plugin: --plugin-ref pins the tag" \
    "jq -e '.extraKnownMarketplaces.northraystudio.source.ref == \"v0.1.0\"' '$PLR/.claude/settings.json'"

  # Merging into an existing settings.json must not drop what is there.
  PLM="$WORK/pluginmerge"
  mkdir -p "$PLM/.claude"
  printf '{"extraKnownMarketplaces":{"mine":{"source":{"source":"github","repo":"me/mine"}}},"enabledPlugins":{"other@mine":true},"permissions":{"allow":["Bash(ls:*)"]}}\n' \
    >"$PLM/.claude/settings.json"
  bash "$SETUP" --target "$PLM" --minimal --plugin >/dev/null 2>&1
  check "plugin: existing marketplace preserved" \
    "jq -e '.extraKnownMarketplaces.mine.source.repo == \"me/mine\"' '$PLM/.claude/settings.json'"
  check "plugin: existing enabledPlugins preserved" \
    "jq -e '.enabledPlugins[\"other@mine\"] == true' '$PLM/.claude/settings.json'"
  check "plugin: new entries added alongside" \
    "jq -e '.enabledPlugins[\"maruda@northraystudio\"] == true and .extraKnownMarketplaces.northraystudio != null' '$PLM/.claude/settings.json'"
  check "plugin: unrelated keys preserved" \
    "jq -e '.permissions.allow[0] == \"Bash(ls:*)\"' '$PLM/.claude/settings.json'"

  # Without the flag, neither key is ever written.
  check "plugin: absent unless requested" \
    "! jq -e '.extraKnownMarketplaces // .enabledPlugins' '$WORK/full/.claude/settings.json'"
fi
check "plugin: rejects --plugin with --with-skills" \
  "! bash '$SETUP' --target '$WORK/plugin' --minimal --plugin --with-skills >/dev/null 2>&1"

# ── 11. Legacy cycle rule is called out ──────
# The installer never deletes files it did not write; it must say so instead.
LG="$WORK/legacyrule"
mkdir -p "$LG/.claude/rules"
printf 'old cycle rule\n' >"$LG/.claude/rules/dev-skills-cycle.md"
bash "$SETUP" --target "$LG" --minimal >"$WORK/legacyrule.out" 2>&1
check "legacy: maruda-cycle.md installed"  "[[ -f '$LG/.claude/rules/maruda-cycle.md' ]]"
check "legacy: old file left untouched"    "grep -q 'old cycle rule' '$LG/.claude/rules/dev-skills-cycle.md'"
check "legacy: deletion is reported"       "grep -q 'legacy dev-skills-cycle.md still present' '$WORK/legacyrule.out'"

# ── 9. Arg validation ────────────────────────
check "args: no flags fails"       "! bash '$SETUP' --target '$WORK' >/dev/null 2>&1"
check "args: bad lang fails"       "! bash '$SETUP' --target '$WORK' --langs rust >/dev/null 2>&1"

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" == "0" ]]
