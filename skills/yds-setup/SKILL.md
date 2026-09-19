---
name: yds-setup
description: "Install the full dev-skills harness into the current project through a short interview: CLAUDE.md, hooks, .claude/settings.json, rules, and skill wiring. Asks — never auto-detects — the languages (Go / Python / TypeScript / JavaScript) and commands, then writes files only after an approved summary. Use when the user asks to set up / install / bootstrap dev-skills, the harness, or the continuous improvement cycle. Triggers: セットアップして, ハーネスを入れて, harnessを入れて, dev-skillsを導入して, プロジェクトを初期化して, '/yds-setup', 'set up the harness', 'install dev-skills', 'bootstrap this project'."
---

# dev-skills Full Harness Setup (Interview Mode)

## Goal

Turn the current repository into a project that runs the
**Diagnose → Register/Draft → Plan → Resolve ⇄ Verify** cycle with
mechanical guardrails (hooks) and a lean CLAUDE.md.

Skills alone are L1. This setup adds L2–L3: a short project brain
(CLAUDE.md), hard rails (hooks + settings), and cycle guidance (rules).
It never creates scheduled or cron-driven automation (L4); event-driven
GitHub Actions — strict CI and the opt-in PR Agent review — are L2–L3 and
in scope.

## Principles

- **Interview, no auto-detection.** Do NOT infer languages from `go.mod`,
  `package.json`, etc., even when they exist. This setup targets
  pre-development projects where detection misleads. File existence is
  used only for overwrite/merge prompts.
- **Never overwrite** existing CLAUDE.md / settings / hooks without
  explicit per-file approval. Prefer merge (append missing sections).
- Hooks enforce hard rules; CLAUDE.md holds soft guidance. Keep
  CLAUDE.md short — detail lives in skills and `.claude/rules/`.
- Write files **only after** the user approves the Phase 4 summary.

## Workflow

Ask one phase at a time and wait for answers. If the user says
"use defaults", still require the primary language choice, then apply
the defaults table below to everything else.

### How to ask (question-tool contract)

When a structured question tool (e.g. AskUserQuestion) is available, use one
call per phase, and keep every call within the tool's contract — violating it
aborts the turn with "Invalid tool parameters":

- At most 4 questions per call; **every question needs 2–4 predefined
  options** — never an empty or single-option list. A free-text "Other"
  choice is provided by the tool automatically; rely on it for custom values
  instead of inventing an "enter manually" option list.
- Free-form items (project name, custom commands) must still offer 2+
  options: make option 1 the recommended default (e.g. "Use directory name:
  <dir> (Recommended)") and a sensible alternative; custom values arrive via
  the built-in Other.
- Multi-choice items (additional languages, components) use the tool's
  multi-select mode.
- If the tool is unavailable or returns an error, fall back to asking the
  same questions as plain chat text and wait for the answers — never skip a
  phase because the tool failed.

### Phase 0 — Preconditions

1. Confirm the target is a git repository (offer `git init` if not).
2. Check existence (existence only — do not read to guess the stack) of:
   `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/`,
   `.claude/rules/dev-skills-cycle.md`, `.claude/skills/`.
3. Tell the user: existing files will each get an overwrite/merge/skip
   question in Phase 3.

### Phase 1 — Project skeleton (required)

- **Q1. Project name** — options: "Use directory name: <dir> (Recommended)" /
  "Use repository name" (custom names come via Other).
- **Q2. Primary language (choose exactly one):**
  Go / Python / TypeScript / JavaScript.
- **Q3. Additional languages** (multi-select) — none, or any others from the
  same list.
- **Q4. Default branch** — options: `main` (Recommended) / `master`
  (anything else via Other).

### Phase 1b — Flow (second call; Phase 1 is already at the 4-question limit)

- **Q5. Integration branch** — the branch PRs target and CI gates. Options:
  "Same as the default branch: <branch> (Recommended)" / `staging`
  (anything else via Other). It is recorded in CLAUDE.md, not detected.
- **Q6. Default flow when several Issues run at once** — options:
  `individual` (Recommended — one PR per Issue) / `batch` (collect them on
  `epic/<n>-<slug>`, verify as a whole, one PR) / `stack` (each PR targets
  the branch of the Issue it depends on). This is only the default: whether
  Issues are batched is decided by asking "do these ship together?", never
  by the dependency graph.

### Phase 2 — Per-language commands

Ask for the primary language in full; for additional languages a quick
confirm of the defaults is enough. Propose these defaults:

| Language        | Install            | Test                | Lint                                          | Format (hook)                  |
| --------------- | ------------------ | ------------------- | --------------------------------------------- | ------------------------------ |
| Go              | `go mod download`  | `go test ./...`     | `golangci-lint run` (fallback `go vet ./...`) | `goimports` (fallback `gofmt`) |
| Python (uv)     | `uv sync`          | `uv run pytest`     | `uv run ruff check`                           | `uv run ruff format`           |
| Python (pip)    | `pip install -e .` | `pytest`            | `ruff check`                                  | `ruff format`                  |
| Python (poetry) | `poetry install`   | `poetry run pytest` | `poetry run ruff check`                       | `poetry run ruff format`       |
| TypeScript      | `{pm} install`     | `{pm} test`         | `{pm} run lint`                               | Prettier                       |
| JavaScript      | `{pm} install`     | `{pm} test`         | `{pm} run lint`                               | Prettier                       |

- Node projects: ask the package manager first (pnpm / npm / yarn / bun;
  propose pnpm), then substitute `{pm}`.
- TypeScript only: also ask about typecheck (`{pm} exec tsc --noEmit` /
  a script name / none).
- Python only: ask the package manager (uv / pip / poetry; propose uv).
  If uv, ask: "Enable a hook that blocks `pip install` in favor of
  `uv add`?" (Y/n).

### Phase 3 — Harness scope

- **Q-H1. Components** (multi-select, every entry recommended ON by default):
  CLAUDE.md / skills (`npx skills add ymd38/dev-skills --skill '*' --agent claude-code -y --copy`) /
  format hook / bash-guard hook / SessionStart + Stop guidance hooks /
  `.claude/rules/` (cycle contract + score-aligned coding principles +
  per-language rules for the chosen languages) /
  GitHub Actions CI (`ci.yml` per language + `security-scan.yml` +
  `.gitleaks.toml` + `.semgrepignore`; gitleaks and semgrep are hard
  gates from day one — shift-left — while trivy starts as informational
  `continue-on-error`) /
  .env guard (`.gitignore` entries + `.env.example`).
- **Q-H1b. Optional paid add-on** (default OFF; independent of the CI
  answer — it composes with a project's existing CI): PR Agent
  (`.github/workflows/pr-agent.yml` + `.pr_agent.toml`; advisory
  qodo-ai/pr-agent review — describe / review / improve when a PR opens,
  `/review` on each push, slash commands for repository members). Needs an
  `OPENAI_KEY` repository secret and API billing; it is advice, never a
  required status check.
- **Q-H2. Per existing file**: merge (append only the missing sections) /
  back up then replace / skip.
- **Q-H3. Bash guard strength**: standard (rm -rf /, force-push to the
  default branch, redirects into `.env`) / standard + pip guard (uv
  projects) / none.

### Phase 4 — Confirm, then apply

Show a summary of every answer and every file that will be created or
modified. Wait for explicit approval. On approval, apply as follows.

**Preferred path — run the installer, then refine:**

1. Locate `harness/scripts/setup.sh`:
   - in this repo if it _is_ dev-skills or contains a clone/submodule, else
   - fetch via the official one-liner (network required):

     ```bash
     curl -fsSL https://raw.githubusercontent.com/ymd38/dev-skills/main/harness/scripts/install.sh \
       | bash -s -- --langs <langs> --pm <pm> --python-pm <py-pm> --branch <branch> --name <name> \
         [--integration-branch <branch>] [--default-flow <individual|batch|stack>] \
         [--guard-pip] [--with-skills] [--pr-agent]
     ```

   Map EVERY Phase 1b / Phase 3 answer to a flag — the applied changes must equal the
   approved summary exactly: languages (primary first) → `--langs`,
   Node PM → `--pm`, Python PM → `--python-pm`, pip guard → `--guard-pip`,
   integration branch → `--integration-branch` (omit when it equals the
   default branch), default flow → `--default-flow`,
   skills ON → `--with-skills`, CI OFF → `--no-ci`, format hook OFF →
   `--no-format-hook`, bash guard OFF → `--no-bash-guard`, guidance hooks
   OFF → `--no-guidance-hooks`, rules OFF → `--no-rules`, .env guard OFF →
   `--no-env-guard`, PR Agent ON → `--pr-agent` (allowed with `--no-ci`,
   never with `--minimal`). If the user wants branch protection applied and `gh`
   is authenticated with admin rights, add `--protect`.
   The installer never overwrites existing files, which is exactly the
   merge-safe behavior wanted here.

2. Then reconcile whatever the installer reported as "kept existing" or
   "proposed" against the user's Phase 3 answers:
   - The installer never overwrites: files that differ from the incoming
     version are written as `<file>.new`. For each one, show the user the
     diff and offer to merge it (or discard the `.new`) — apply only what
     they approve, then delete the `.new` file.
   - CLAUDE.md kept + user chose **merge** → append only the missing
     sections (Stack & commands for the chosen languages, the cycle
     section, Hard rules), following `harness/templates/CLAUDE.md.template`.
   - settings kept unmerged (no jq) → merge the `hooks` block by hand,
     preserving every existing user hook.
   - Any file the user chose to **skip** → leave untouched even if the
     installer would have created it (delete nothing; just don't add).
3. Adjust generated CLAUDE.md commands to any non-default answers from
   Phase 2 (e.g. a custom test script name).

**Fallback (no network, no local copy):** report that the harness
templates are unavailable and stop after writing only what can be
written faithfully from this document — do not improvise hook scripts
from memory.

### Phase 5 — Verify and report

Print a final checklist:

```
[dev-skills harness]
  skills:     OK (N) / MISSING
  CLAUDE.md:  CREATED / MERGED / SKIPPED
  hooks:      OK (selected scripts, executable)
  settings:   OK / MERGED / needs manual merge
  rules:      OK / skipped
  CI:         OK / skipped
  flow:       integration branch: <branch> | default: <individual|batch|stack>
  protection: configured / NOT CONFIGURED / applied
  pr-agent:   disabled / written (OPENAI_KEY secret required)
  next:       restart Claude Code to load hooks, then try /yds-software-evaluation .
```

Two follow-ups matter for the gates to actually gate:

- **Branch protection.** A CI check only blocks merges once it is a
  required status check. The installer reports the state; if it says
  NOT CONFIGURED, treat setup as incomplete and either re-run with
  `--protect` (needs `gh` auth + admin + a pushed default branch) or walk
  the user through GitHub settings. Do not report overall success while
  protection is unconfigured — report it as an explicit remaining step.
- **Strict CI.** The generated jobs intentionally fail when lint /
  typecheck / test scripts (or any tests) are missing. Tell the user the
  first code PR must land with those in place — that is the shift-left
  contract, not a bug.

- **PR Agent secret.** If `--pr-agent` was applied, the `PR Agent` workflow
  fails on every PR until the `OPENAI_KEY` repository secret exists. Report
  it as an explicit remaining step; it is advisory and must never be added
  to required status checks.

Remind the user that hooks load at session start — a restart (or new
session) is needed before the guard/format hooks take effect.

## Stop conditions

- User declines the Phase 4 summary → stop after reporting what _would_
  have changed. Write nothing.
- User declines an overwrite → keep the file, note it in the checklist.
- Unknown/other language requested → set up the supported languages,
  leave a `# TODO` stack block for the rest, and say so.

## Non-goals

- No scheduled loops or cron (L4) — separate task only. Event-driven GitHub
  Actions (CI, PR Agent) are in scope.
- No Semgrep / gh installation — mention prerequisites, don't install.
- No rewriting of existing architecture docs or unrelated refactors.
