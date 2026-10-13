# The continuous improvement cycle — the details

The [README](../README.md#the-cycle) has the diagram and the three rules. This
page walks through each step, the verification loop, the batch flow, and what
every skill emits.

- [Steps](#steps)
- [The verification loop](#the-verification-loop)
- [One Issue or several](#one-issue-or-several)
- [What each skill does](#what-each-skill-does)
- [Triggers](#triggers)

## Steps

| Step | Skill | What happens |
| --- | --- | --- |
| **Diagnose** | `software-evaluation`, `vulnerability-scan`, `data-validation` | Evaluate code quality, security, and data correctness. The first two produce reports + JSON summaries; `data-validation` is session-output only by design |
| **Visualize** | `progress-dashboard` | Generate an interactive HTML dashboard from JSON summaries to track improvement trends |
| **Register** | `report-to-issues` | Parse reports, deduplicate against existing issues, create GitHub Issues |
| **Draft** | `gh-issue-drafter` | Turn a rough, hand-written intent into a scoped Issue (Done / Out of scope / Design constraints) — the human-authored entry point into the cycle |
| **Plan** | `gh-issue-planner` | Investigate the issue, propose a structured response plan, post the agreed plan as an issue comment |
| **Resolve** | `gh-issue-resolver` | Pick up the agreed plan comment, create a branch, implement, run tests, open a PR |
| **Batch run** | `gh-batch-runner` | Only when several Issues ship together: collect them as sub-issues of an Epic, implement in dependency order on `epic/<n>-<slug>`, verify the branch as a whole, open one PR into the integration branch |
| **Verify** | `gh-issue-resolver` (Step 8) | Re-run the triggered diagnoses on the diff, attribute each finding, **autonomously fix the regressions this change caused**, and hand pre-existing findings to `report-to-issues`. Bounded to 3 iterations and the agreed plan's impact scope |

`spec-doc` is independent of this cycle — use it anytime to generate or sync
living documentation. `setup` is also independent: it installs the harness
that makes this cycle the default path in a new project.

Skills hand off to each other through HTML-comment markers embedded in Issue
and PR comments (`<!-- gh-issue-drafter:scoped-issue -->`,
`<!-- gh-issue-planner:agreed-plan -->`, and so on). They are what lets the
resolver find the agreed plan months later, so they never change.

## The verification loop

The `Resolve ⇄ Diagnose` arrows in the diagram are the autonomous verification
loop. After opening the PR, `gh-issue-resolver`:

1. Re-runs whichever diagnoses the diff triggers (`data-validation` for schema,
   model, query or fixture changes; `vulnerability-scan` for auth, input
   handling, queries, file paths, outbound requests or dependencies;
   `software-evaluation` when the Issue came from it), passing the base branch
   as the baseline.
2. Classifies every finding: **regression** (passes on the base, fails now),
   **pre-existing** (fails on the base too), **environmental** (fixture or tool
   missing), or **unknown** (no baseline).
3. Fixes **regressions only**, in severity order, with the minimal upstream fix
   — never by loosening a constraint, deleting an assertion or relaxing a
   threshold. Up to 3 iterations, never outside the agreed plan's impact scope.
4. Reports pre-existing and environmental findings and offers to file them via
   `report-to-issues`. They are never fixed in the same PR.

When the loop cannot close — budget exhausted, or a fix would leave the agreed
scope — it stops, leaves the branch and PR in place, and returns to
`gh-issue-planner`. Scope is widened by a new plan, never by the resolver.

## One Issue or several

Three flows. The flow is chosen by asking "do these ship together?", never
derived from the dependency graph. The repository default lives in `CLAUDE.md`
(`setup.sh --default-flow`), so the question is only asked when the answer is
not the default.

| Flow | When | How |
| --- | --- | --- |
| **individual** | No dependency between the Issues, and they may ship separately | One PR per Issue into the integration branch |
| **batch** | They should ship together | Collect every Issue's change on `epic/<n>-<slug>`, verify the branch as a whole, then one PR into the integration branch |
| **stack** | A chain of dependencies, but they do not ship together | Each PR targets the branch of the Issue it depends on |

In a batch, `gh-batch-runner` collects the members under an Epic Issue
(sub-issues are the membership, GitHub `blocked_by` is the order, both re-read
at the start of every run), lands one commit per Issue on the shared `epic/**`
branch, verifies that branch as a whole against the integration branch — what
newly breaks there is the batch's regression and is fixed under the usual
limits, what already failed goes to `report-to-issues` — and opens a single PR.
No child PRs; CI and review run once, on the PR into the integration branch.
Branch protection does not apply to `epic/**` by design: the gate is that PR.

## What each skill does

### Diagnose

- `software-evaluation` — Scores a codebase across five pillars (Architecture,
  Reliability, Observability, Security, DX) with evidence-based findings
  (file:line citations required). Produces a 1–10 scorecard, a prioritized
  roadmap with P0–P3 action items, and a JSON summary for the dashboard.
- `vulnerability-scan` — Combines automated Semgrep scanning with a manual
  review checklist covering OWASP Top 10. Triages true positives from false
  positives, includes a dependency CVE audit, and emits a JSON summary.
- `data-validation` — Checks record counts, NULL rates (including empty
  strings, zero values, and sentinels), value distribution, uniqueness,
  referential integrity, and format validity. Reads only from the project's
  own fixtures/seeds or an explicitly configured non-production connection —
  never a guessed or production source. Every finding carries up to 5 sampled
  rows with PII masked, and every expectation is traced back to a schema
  constraint, type definition, or test assertion. Classifies each finding as
  `regression` / `pre-existing` / `environmental` so `gh-issue-resolver` knows
  what it is allowed to fix. **Writes no JSON and, by default, no file at
  all** — routine validation should not grow the commit target.

### Visualize

- `progress-dashboard` — Reads JSON summaries from `software-evaluation` and
  `vulnerability-scan`, then generates a self-contained HTML dashboard with
  quality score trends, radar charts, security findings trends, roadmap
  progress, and dependency risk panels. See
  [`examples/progress-dashboard/`](../examples/progress-dashboard/).

### Issues

- `report-to-issues` — Decomposes evaluation or security-audit reports into
  actionable tasks, presents them for user selection, and registers the chosen
  items as GitHub Issues with appropriate labels and priority.
- `gh-issue-drafter` — Takes a loose, hand-written "what I want" and drafts the
  structure it almost always lacks (machine-checkable Done conditions, Out of
  scope, optional Design constraints). After author approval, files the Issue
  tagged with `<!-- gh-issue-drafter:scoped-issue -->` so `gh-issue-planner`
  treats the scope as binding. When the draft shows signs of being too large
  (more than three or independent Done conditions, mixed types, no usable Out
  of scope), it offers to keep one Issue, split into independent Issues, or
  file an Epic with sub-issues — the Epic only when the parts ship together,
  which makes it the entry point to `gh-batch-runner`. The human-authored
  counterpart to `report-to-issues`.
- `gh-issue-planner` — Fetches a GitHub Issue via `gh` CLI, classifies it
  (bug/feature/refactor/docs), searches related code, runs the "check before
  building" ladder to decide how far to build, and presents a structured plan
  (approach, how far to build, impact scope, steps, open questions). Posts the
  agreed plan as an issue comment tagged with
  `<!-- gh-issue-planner:agreed-plan -->`. Several Issues at once produce one
  comment per Issue.
- `gh-issue-resolver` — Picks up the agreed plan comment, creates a feature
  branch in a temporary worktree, applies the changes, runs tests, opens a Pull
  Request, and runs the [verification loop](#the-verification-loop).
- `gh-batch-runner` — Runs several planned Issues as one release, as described
  under [One Issue or several](#one-issue-or-several).

### Documentation and setup

- `spec-doc` — Generates a machine-readable "Living Specification"
  (`docs/spec.md`) from source code. Covers architecture, interfaces, data
  models, state transitions, and development constraints. Syncs with existing
  specs rather than replacing them.
- `setup` — Installs the full harness into the current project through a short
  interview: a lean `CLAUDE.md` (Stack & commands, cycle, hard rules), four
  hooks (format-on-write, dangerous-bash guard, SessionStart context, Stop
  nudge), a merged `.claude/settings.json`, and `.claude/rules/maruda-cycle.md`.
  Languages (Go / Python / TypeScript / JavaScript) are asked, never
  auto-detected; nothing is written before the confirmation summary is
  approved. The non-interactive counterparts are `harness/scripts/install.sh`
  (one-liner) and `harness/scripts/setup.sh`.

## Triggers

Describe the task and the matching skill is applied:

```
"Generate a spec for src/api/"                                → spec-doc
"Review the code quality of src/backend/"                     → software-evaluation
"Scan src/ for security vulnerabilities"                      → vulnerability-scan
"Check the data quality of db/" / "データ検証して" / "NULL率を調べて" → data-validation
"Create GitHub Issues from docs/evaluation/myapp.20260406.md" → report-to-issues
"Turn this into an issue" / "ざっくり書くのでIssueにして"          → gh-issue-drafter
"Plan issue #42" / "Issue #42の対応方針を立てて"                   → gh-issue-planner
"Implement issue #42" / "Issue #42を実装して"                     → gh-issue-resolver (needs an agreed plan comment)
"Issue 1,2,3をまとめて対応して" / "Ship these issues as one release" → gh-batch-runner (needs a plan on every member)
"Generate a progress dashboard" / "Show improvement trends"   → progress-dashboard
"Set up the harness" / "セットアップして" / "ハーネスを入れて"       → setup
```
