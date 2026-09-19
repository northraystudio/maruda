---
name: yds-gh-issue-planner
description: "Fetch a GitHub Issue by ID using the gh CLI, investigate related code, propose a structured response plan (policy, impact scope, implementation steps), and post the agreed plan as a comment on the issue. Implementation/PR creation is out of scope — use yds-gh-issue-resolver for that. Use when the user provides a GitHub Issue ID or asks to investigate/analyze/plan a GitHub Issue. Triggers include issue IDs like #42 or 'issue 42', requests such as Issueを調査して / Issueの対応方針を立てて, analyze issue #N, plan issue #N, investigate issue, look at issue. Accepts several Issues at once (e.g. '1,2,3' or 'Issue 1と2を計画して'): it investigates once and posts one agreed-plan comment per Issue."
---

# GitHub Issue Planner

## Overview

Fetch a GitHub Issue, analyze its content, investigate related code in the repository, and present a structured response plan to the user. After the user confirms, post the agreed plan as a comment on the issue. Implementation and PR creation are out of scope — use `yds-gh-issue-resolver` for those steps (or `yds-gh-batch-runner` when several Issues ship together).

Several Issues may be planned in one pass. The agreed-plan granularity never changes: **one comment per Issue**, so every downstream skill keeps reading exactly one plan per Issue. See *Step 7*.

## Workflow

### Step 1: Fetch the Issue

Run the following command (replace `<id>` with the issue number):

```bash
gh issue view <id> --json number,title,body,labels,assignees,state,url,comments
```

When several Issue numbers were given, run this once per Issue and keep the results
side by side — the investigation in Step 3 is shared, the plans in Step 4 are not.

If no repository context is clear, also run:

```bash
gh repo view --json nameWithOwner
```

Extract from the response:
- **Title** and **body**: the core problem statement
- **Labels**: bug / feature / enhancement / etc. — determines response approach
- **Comments**: additional context, workarounds, or constraints from stakeholders

**Pre-scoped Issues:** if the body contains `<!-- gh-issue-drafter:scoped-issue -->`,
the Issue was drafted via `yds-gh-issue-drafter` and its scope is author-approved. Treat its
sections as binding input to the plan:
- **完了条件 (Done)** — the contract the plan must satisfy; every condition must be
  covered by an implementation step or a test in the plan
- **触らない範囲 (Out of scope)** — hard boundaries; reject any plan direction that
  crosses them
- **設計方針 (Design constraints)** — constraints on how, not just what

Do not re-ask the user about scope that these sections already answer — raise open
questions only for genuinely new information discovered during investigation.

### Step 1.5: Read the dependencies

Dependencies and parent/child links live on the Issue, not in the plan. Read the current
state — they may have been recorded after the Issue was filed:

```bash
gh api repos/{owner}/{repo}/issues/<id>/dependencies/blocked_by --jq '.[].number'
gh api repos/{owner}/{repo}/issues/<id>/sub_issues --jq '.[].number'
```

If the investigation uncovers a dependency that is not recorded yet, record it before
planning around it (`<blocker-id>` is the blocking Issue's **id**, not its number —
read it with `gh issue view <blocker-number> --json id`):

```bash
gh api -X POST repos/{owner}/{repo}/issues/<id>/dependencies/blocked_by -f issue_id=<blocker-id>
```

A plan that silently assumes an unrecorded dependency is a plan the batch and stacked
flows cannot reproduce.

### Step 2: Classify the Issue

Determine issue type to guide the investigation strategy:

| Label / Signal | Type | Investigation Focus |
|---|---|---|
| bug, error, crash | Bug fix | Error paths, edge cases, affected callers |
| feature, enhancement | New feature | Insertion points, interface contracts, related modules |
| refactor, tech-debt | Refactoring | Current usage sites, test coverage |
| docs, documentation | Docs update | Existing docs, code references |

### Step 3: Investigate Related Code

Extract keywords from the title and body, then search the codebase:

1. Use `code_search` with natural-language queries derived from the issue
2. Use `grep_search` for specific function/class/variable names mentioned
3. Use `read_file` to deeply understand the most relevant files
4. Trace call chains and dependencies to establish impact scope

Focus on:
- Files and functions directly mentioned or implied in the issue
- Callers / consumers of affected code
- Tests covering the affected area

### Step 4: Present the Response Plan

Present the following structured plan to the user in their preferred language:

```
## Issue #<id>: <title>

### 対応方針 (Approach)
<What will be done and why — 2-4 sentences>

### 影響範囲 (Impact Scope)
- **変更対象ファイル**: list of files to modify
- **影響を受けるモジュール**: related modules that may be affected
- **テスト**: existing tests to update + new tests to add

### 実装方法 (Implementation Steps)
1. <Concrete step>
2. <Concrete step>
3. ...

### 懸念事項・確認事項 (Open Questions)
- <Any ambiguity or assumption that needs user confirmation>
```

### Step 5: Confirm and Iterate

- If there are open questions, **ask the user before proceeding**
- Adjust the plan based on feedback
- Once the user explicitly confirms, proceed to Step 6

### Step 6: Post the Agreed Plan to the Issue

After the user confirms the plan, post it as a comment on the GitHub Issue:

```bash
gh issue comment <id> --body "$(cat <<'EOF'
## 対応方針

<agreed approach>

## 影響範囲

- **変更対象ファイル**: <files>
- **影響を受けるモジュール**: <modules>
- **テスト**: <tests>

## 実装方法

1. <step>
2. <step>

---
<!-- gh-issue-planner:agreed-plan -->
*Generated by `yds-gh-issue-planner` — this comment represents the agreed implementation plan. Use `yds-gh-issue-resolver` to implement it.*
EOF
)"
```

### Step 7: Several Issues at once

When more than one Issue was given, investigate once (Step 3) and then produce **one
agreed-plan comment per Issue** — never a single combined plan. Each comment keeps the
`<!-- gh-issue-planner:agreed-plan -->` marker, so `yds-gh-issue-resolver` and
`yds-gh-batch-runner` read plans exactly as they do for a single Issue.

1. Present all plans together in one message so the user confirms once.
2. Make sure each plan's 影響範囲 states what it shares with its siblings — overlapping
   files are what turns an individual flow into a batch.
3. Ask **"do these ship together?"** — the answer picks the flow, not the dependency
   graph. Skip the question when the repository default in CLAUDE.md already answers it:

   | Answer | Flow | Hand off to |
   |---|---|---|
   | Yes, one release | **batch** | `yds-gh-batch-runner` |
   | No, and they are independent | **individual** | `yds-gh-issue-resolver` per Issue |
   | No, but one depends on another | **stack** | `yds-gh-issue-resolver` with the dependency's branch as base |

4. Record any dependency found while planning (Step 1.5) before handing off.
5. Post each comment only after the user confirms (Step 6, once per Issue).

This completes the planner workflow. If implementation is required, hand off to the `yds-gh-issue-resolver` skill, which uses the posted comment as its agreed plan — or to `yds-gh-batch-runner` when the Issues ship together.

## Key Principles

- **Never post the comment without user confirmation** when open questions exist
- **One agreed-plan comment per Issue**, even when several Issues are planned together
- Record dependencies on the Issue (`blocked_by` / sub-issues), never only in prose
- Keep the plan concise — avoid over-engineering
- If the issue is vague, ask one focused clarifying question rather than multiple at once
- Prefer minimal, upstream fixes over downstream workarounds
