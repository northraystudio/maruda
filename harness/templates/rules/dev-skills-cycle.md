# Continuous improvement cycle — rules & conventions

## Cycle

- Diagnosis skills (`yds-software-evaluation`, `yds-vulnerability-scan`,
  `yds-data-validation`) produce evidence; they never silently rewrite the codebase.
- Implementation requires an agreed plan comment from `yds-gh-issue-planner`
  (`<!-- gh-issue-planner:agreed-plan -->`). Do not widen scope beyond it.
- `yds-gh-issue-resolver` may fix **regression** findings only, ≤3 iterations,
  within the plan's impact scope. Pre-existing findings → `yds-report-to-issues`
  after user approval — never fixed in the same PR.
- Never relax tests, types, or thresholds to greenwash a check.
- Living docs anytime: `/yds-spec-doc`. Trends: `/yds-progress-dashboard`.

## Conventions

- Branch names: `<type>/<issue-number>-<summary>` (e.g. `feat/42-user-auth`).
- Record requirement and design decisions ("why we chose X") as ADRs in
  `docs/adr/NNNN-<slug>.md` (Context / Decision / Consequences), committed
  and reviewed via PR. Small, issue-scoped decisions stay in the
  `yds-gh-issue-planner` agreed-plan comment; agent auto-memory is for
  personal working preferences only, never for project decisions.
- Security-scan false positives: allowlist the smallest unit (exact value /
  rule id, `# nosemgrep: <rule-id>` with a reason) — never a whole file or
  directory, and never by weakening the gate.
- Supply chain: pin tool and action versions in CI (no `@latest`).
