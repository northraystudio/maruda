---
name: yds-gh-issue-resolver
description: "Implement and verify a fix for a GitHub Issue whose response plan has already been posted as a comment by yds-gh-issue-planner. Creates a feature branch, applies the agreed plan, runs tests, and opens a Pull Request. Use when the user asks to implement/fix/resolve a planned GitHub Issue. Triggers include requests such as Issueを実装して / Issueを修正して / Issueを対応して, implement issue #N, fix issue #N, resolve issue #N, work on issue #N. Prerequisite: an agreed plan comment must exist on the issue (run yds-gh-issue-planner first if not)."
---

# GitHub Issue Resolver

## Overview

Implement and verify a fix for a GitHub Issue, starting from the agreed response plan that `yds-gh-issue-planner` has already posted as a comment on the issue. This skill creates a feature branch, uses a git worktree as a temporary implementation sandbox, runs tests, opens a Pull Request, and verifies the fix against the original issue.

## Prerequisites

- The target issue must have an **agreed plan comment** previously posted by `yds-gh-issue-planner`, identified by the HTML marker `<!-- gh-issue-planner:agreed-plan -->` near the end of the comment body.
- If no such comment exists, **stop and direct the user to run `yds-gh-issue-planner` first**. Do not improvise an unagreed plan in this skill.

## Workflow

### Step 1: Fetch the Issue and Agreed Plan

Run the following command (replace `<id>` with the issue number):

```bash
gh issue view <id> --json number,title,body,labels,state,url,comments
```

From the `comments` array:
1. Locate the most recent comment whose body contains the marker `<!-- gh-issue-planner:agreed-plan -->`.
2. Treat that comment as the **agreed plan** and extract the 対応方針 / 影響範囲 / 実装方法 sections.
3. If no such comment exists, abort with a message asking the user to run `yds-gh-issue-planner` first.

### Step 2: Branch and Worktree Setup

Resolve `<base-ref>` first — everything downstream (the branch, the PR's base, and the
verification baseline in Step 8) is measured against it:

| Flow | `<base-ref>` |
|------|--------------|
| individual (default) | the integration branch recorded in CLAUDE.md, falling back to the default branch |
| stack | the branch of the Issue this one depends on |
| batch | the epic branch, passed in by `yds-gh-batch-runner` |

```bash
# 1. Create a branch from <base-ref> (without switching the main working tree)
git branch <branch-name> <base-ref>
# Examples: fix/42-add-timeout-to-fetch  feat/15-user-export-api

# 2. Create an isolated worktree from that branch
git worktree add ../<branch-name> <branch-name>
```

Branch naming convention:
- Bug fixes: `fix/<id>-<short-description>`
- Features: `feat/<id>-<short-description>`
- Refactors: `refactor/<id>-<short-description>`

All implementation work (Steps 3–4) is performed inside the worktree directory `../<branch-name>`. The main working tree stays on its current branch throughout.

### Step 3: Implementation

Apply the changes defined in the agreed plan inside the worktree directory. Follow these rules:
- Make minimal, focused changes — do not scope-creep beyond the agreed plan
- Run existing tests after each logical change to catch regressions early
- Add or update tests to cover the changed behavior
- If the agreed plan turns out to be infeasible or incomplete, **stop and return to `yds-gh-issue-planner`** rather than silently expanding the scope here

### Step 4: Test Verification

```bash
# Run tests relevant to the changed area (inside the worktree directory)
# Ensure no regressions in existing tests
# Verify new tests pass
```

If tests fail, diagnose and fix before proceeding. Do not skip failing tests.

**If the change is data-related** (see the trigger list in Step 8.1), also run
`yds-data-validation` here — inside the worktree, while the main working tree still holds the
base branch and attribution is cheapest:

```
/yds-data-validation <changed-data-scope>   # baseline: <base-ref>
```

Treat a `regression`-class FAIL exactly like a failing test: fix it now, do not proceed with
it outstanding. Step 8 re-runs the check as the final gate.

### Step 5: Teardown Worktree and Switch to Branch

After tests pass, remove the worktree and switch the main working tree to the feature branch:

```bash
# Remove the worktree — the branch and its commits are preserved
git worktree remove ../<branch-name>

# Switch the main working tree to the feature branch
git checkout <branch-name>
```

The main working tree now reflects the implemented changes.

### Step 6: Visual Verification

Run the application in the normal development environment and verify the fix on screen. Confirm the fix addresses the acceptance criteria in the original issue.

### Step 7: Create a Pull Request

```bash
gh pr create --base <base-ref> --title "<type>(#<id>): <short description>" --body "$(cat <<'EOF'
## Summary
<What was changed and why — reference the issue>

Closes #<id>

## Changes
- <file>: <what changed>
- <file>: <what changed>

## Testing
- [ ] Existing tests pass
- [ ] New tests added for changed behavior
- [ ] Manual verification completed
EOF
)"
```

### Step 8: Verify (autonomous)

Verification is not a suggestion to the user — it is work this skill performs. Re-run the
diagnosis, read the result, and **fix what this change broke**, without waiting to be asked.

Start with the basics:

1. **Re-read the issue description and acceptance criteria** — does the implementation fully address them?
2. **Run the full test suite** — no regressions introduced

Then run the autonomous verification loop below.

#### 8.1 Decide which diagnoses to re-run

Re-run a diagnostic skill when **any** of its triggers is present in the diff:

| Skill | Re-run when the diff touches |
|-------|------------------------------|
| `yds-data-validation` | migrations, DDL, schema files, ORM models/entities, serializers/DTOs, queries, fixtures/seeds/factories, import-export or ETL code, validation rules, or any column/field rename or type change |
| `yds-vulnerability-scan` | the issue originated from `yds-vulnerability-scan`, **or** the diff touches auth, input handling, queries, file paths, outbound requests, headers/cookies, or dependencies |
| `yds-software-evaluation` | the issue originated from `yds-software-evaluation` |

Run every skill whose triggers fire. If none fire, skip to 8.5.

#### 8.2 Run the diagnosis

Run each selected skill against the changed scope, **passing `<base-ref>` from Step 2 as the
baseline** so attribution is possible. The baseline is always what this branch was cut from —
in a batch that is the epic branch, so a finding that already fails there is pre-existing for
this Issue:

```
/yds-data-validation <changed-data-scope>     # baseline: <base-ref>
/yds-vulnerability-scan <changed-path>
/yds-software-evaluation <changed-path>
```

`yds-data-validation` writes no file in this mode — read its session output directly. Parse the
fixed header block it emits:

```
<!-- data-validation:result -->
RESULT: PASS | WARN | FAIL
```

and its attribution table:

```
<!-- data-validation:attribution -->
| ID | Class | Basis |
```

#### 8.3 Classify every finding before touching anything

| Class | Meaning | Action |
|-------|---------|--------|
| **regression** | Passes on the base, fails now — **this change caused it** | **Fix autonomously** (8.4) |
| **pre-existing** | Fails on the base too | **Do not fix.** Collect for 8.6 |
| **environmental** | Fixture missing, tool absent, connection unavailable | **Do not fix.** Report in 8.6 |
| **unknown** | No baseline was available | **Do not fix.** Treat as pre-existing |

**Only `regression` is in scope.** Fixing a pre-existing finding here is scope creep, and it
buries an unrelated defect inside this PR's diff.

#### 8.4 Fix regressions autonomously — bounded loop

For each `regression` finding, in severity order:

1. Confirm the fix stays **inside the agreed plan's 影響範囲**. If it cannot, stop immediately
   and go to 8.7 — do not widen the scope on your own authority.
2. Apply the minimal upstream fix. Follow the finding's *Remediation direction* when given.
   **Fix the writer, not the contract** — loosening a constraint, deleting an assertion, or
   relaxing a threshold to make a check pass is never an acceptable fix.
3. Re-run the affected tests, then re-run the diagnosis from 8.2.
4. If new `regression` findings appear, they count toward the same budget.

**Attempt budget: 3 iterations of the whole loop.** Count an iteration each time you return to
8.2 after applying fixes. Then:

- **All regressions cleared** → continue to 8.5
- **Budget exhausted with regressions outstanding** → stop and go to 8.7
- **A fix would require leaving the agreed plan's impact scope** → stop immediately and go to 8.7

Never spend the budget re-attempting the same fix. If two consecutive iterations produce the
same finding with the same remediation, the plan is wrong — go to 8.7 now rather than burning
the third attempt.

#### 8.5 Update the PR

Amend the PR body with what verification found and what was fixed in response, so the
autonomous edits are visible to the reviewer rather than buried in the commit log:

```markdown
## Verification
- Full test suite: pass
- yds-data-validation: FAIL → PASS (2 regressions fixed: D-01, D-03)
- yds-vulnerability-scan: not triggered
```

#### 8.6 Hand off what is out of scope

`pre-existing` and `environmental` findings are real, and dropping them silently is how they
survive forever. Report them, and offer to file them — **but do not create Issues without the
user's confirmation**:

```
Findings outside this change's scope (not fixed here):

  [pre-existing]   D-02  users.email is empty on 3.2% of rows
  [pre-existing]   D-04  2 future-dated created_at values
  [environmental]  D-05  payments.yml is not loaded by the test setup

Register these as GitHub Issues? (yds-report-to-issues)
```

If the user agrees, hand the findings to `yds-report-to-issues`.

#### 8.7 Stop conditions — return to the planner

When the loop cannot close, **stop and return to `yds-gh-issue-planner`**. Do not merge, do not
mark the issue resolved, and do not paper over the failure:

```
⛔ Verification did not converge for Issue #<id>.

Outstanding regressions:
  D-01  orders.status contains values outside the declared enum  (3 attempts)

Reason: the fix requires changing internal/model/order.go, which is outside the
agreed plan's 影響範囲 (db/migrations/ only).

The agreed plan needs revision. Re-run yds-gh-issue-planner on Issue #<id>.
```

Leave the branch and the PR in place — the planner needs the work to reason about.

#### 8.8 Report completion

```
✅ Implementation complete and verified for Issue #<id>.
   Tests: pass | yds-data-validation: PASS | 2 regressions fixed during verification
```

This closes the improvement cycle loop — and closes it with the fix already applied, not with
a suggestion that someone re-run the diagnosis later.

### Step 9: Cleanup (on explicit user instruction only)

**Do NOT run this step automatically.** Execute only when the user explicitly requests cleanup (e.g., "ブランチを削除して", "マージしたので片付けて", "clean up the branch").

Typical trigger: the PR has been merged and the user is ready to discard the feature branch.

```bash
# Switch back to the default branch
git checkout main   # or master / trunk as appropriate

# Delete the local branch (-d guards against unmerged changes)
git branch -d <branch-name>

# Prune stale remote-tracking refs if the remote branch was already deleted
git fetch --prune
```

## Key Principles

- **Never start implementation without an agreed plan comment** posted by `yds-gh-issue-planner`
- **`<base-ref>` is one decision made once** (Step 2) and reused for the branch, the PR base
  and the verification baseline — never mix two of them
- Stay strictly within the agreed plan — no scope creep
- **Verify autonomously, remediate only regressions.** Re-running the diagnosis and fixing what
  this change broke is this skill's job, not a suggestion handed back to the user. What this
  change did *not* break is not this skill's job — attribution is what separates the two
- **The autonomy is bounded, not open-ended**: 3 loop iterations, and the agreed plan's 影響範囲
  is a hard wall. Hitting either boundary means returning to `yds-gh-issue-planner`, never widening
  the scope unilaterally
- Never skip or weaken failing tests; fix the root cause instead
- **Never relax a constraint, threshold, or assertion to make a check pass** — fix the writer
- Prefer minimal, upstream fixes over downstream workarounds
- The worktree is a temporary sandbox — remove it after tests pass (Step 5), before visual verification
- **Never delete the feature branch without explicit user instruction** — cleanup (Step 9) happens only after the user confirms the PR is merged and ready to discard
