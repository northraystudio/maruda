# Continuous improvement cycle — rules & conventions

## Cycle

- Diagnosis skills (`software-evaluation`, `vulnerability-scan`,
  `data-validation`) produce evidence; they never silently rewrite the codebase.
- Implementation requires an agreed plan comment from `gh-issue-planner`
  (`<!-- gh-issue-planner:agreed-plan -->`). Do not widen scope beyond it.
- `gh-issue-resolver` may fix **regression** findings only, ≤3 iterations,
  within the plan's impact scope. Pre-existing findings → `report-to-issues`
  after user approval — never fixed in the same PR.
- Never relax tests, types, or thresholds to greenwash a check.
- Living docs anytime: `/maruda:spec-doc`. Trends: `/maruda:progress-dashboard`.

## Flow — one Issue or several

Three flows. The flow is **not** derived from the dependency graph: ask "do these
ship together?" and let the answer decide. The repository default lives in
CLAUDE.md, so the question is only asked when the answer is not the default.

| Flow | When | How |
|------|------|-----|
| **individual** | No dependency between the Issues, and they may ship separately | One PR per Issue into the integration branch |
| **batch** | They should ship together | Collect every Issue's change on `epic/<n>-<slug>`, verify the branch as a whole, then one PR into the integration branch |
| **stack** | A chain of dependencies, but they do not ship together | Each PR targets the branch of the Issue it depends on |

- **Dependencies are recorded on the Issue, not in a plan.** Use GitHub's
  `blocked_by` (`gh api repos/{owner}/{repo}/issues/{n}/dependencies/blocked_by`)
  and sub-issues as the source of truth; they can be added or corrected at any
  time, not only while planning. Batch and stack flows **re-read the current
  state when they start**. A dependency discovered mid-implementation is recorded
  on the Issue first — then continue, or stop if it changes the flow.
- **batch membership is an Epic Issue** holding its members as sub-issues, on the
  branch `epic/<n>-<slug>`. The Epic is generated, not hand-written.
- **No child PRs inside a batch.** Each Issue lands as its own commit
  (`<type>(#<n>): ...`); CI and review run once, on the PR into the integration
  branch.
- **Verify twice in a batch**: per Issue as usual, then the whole `epic/**`
  branch before opening the integration PR.
- **Batch regressions are measured against the integration branch.** What newly
  breaks relative to it is the batch's regression and is fixed under the usual
  resolver limits; what already failed on the integration branch goes to
  `report-to-issues` — never fixed in the same PR.
- Branch protection does not apply to `epic/**`. That is expected: the gate is
  the PR into the integration branch, which must pass CI and review.

## Conventions

- Branch names: `<type>/<issue-number>-<summary>` (e.g. `feat/42-user-auth`);
  a batch's integration branch is `epic/<epic-issue-number>-<summary>`.
- Record requirement and design decisions ("why we chose X") as ADRs in
  `docs/adr/NNNN-<slug>.md` (Context / Decision / Consequences), committed
  and reviewed via PR. Small, issue-scoped decisions stay in the
  `gh-issue-planner` agreed-plan comment; agent auto-memory is for
  personal working preferences only, never for project decisions.
- Security-scan false positives: allowlist the smallest unit (exact value /
  rule id, `# nosemgrep: <rule-id>` with a reason) — never a whole file or
  directory, and never by weakening the gate.
- Supply chain: pin tool and action versions in CI (no `@latest`).
