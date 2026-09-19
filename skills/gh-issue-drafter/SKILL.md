---
name: gh-issue-drafter
description: "Turn a rough, hand-written intent into a well-scoped GitHub Issue before planning starts. Takes a loose 'what I want' from the user, proposes the missing structure (Done definition, Out of scope, Design constraints), gets the user's approval, and creates the Issue via the gh CLI with a scoped-issue marker so gh-issue-planner can pick it up. This is the human-authored counterpart to report-to-issues (which registers machine-generated findings). Use when the user wants to file a new Issue from a rough idea, is about to write an Issue by hand, or asks to turn a note/thought into an Issue. Triggers include requests like Issueを起こして / Issueを作って / ざっくり書くのでIssueにして, 'draft an issue', 'create an issue for', 'turn this into an issue', 'file an issue'. Does NOT plan or implement — hand off to gh-issue-planner for the response plan, then gh-issue-resolver for implementation."
---

# GitHub Issue Drafter

## Overview

The quality of everything downstream — the plan, the reviews, the implementation, the
CI verification — is capped by the quality of the Issue that starts it. A rough,
one-line Issue forces every later step to guess at the author's intent.

This skill takes the user's rough intent (the *What*) and, without slowing them down,
proposes the three things a hand-written Issue almost always omits: a machine-checkable
**Done definition**, an explicit **Out of scope**, and optional **Design constraints**.
The user approves or edits the proposal, then the skill creates a structured GitHub
Issue tagged with a marker that `gh-issue-planner` recognizes.

**Scope boundary:** this skill only drafts and files the Issue. It does not investigate
code, propose a response plan, or implement anything. Hand off to `gh-issue-planner`
once the Issue exists.

## When NOT to expand

If the user's input already contains a clear Done definition and scope (e.g. they pasted
a fully-formed Issue, or a `report-to-issues` output), do not re-interrogate them — just
confirm and file. The goal is to fill gaps, not to add ceremony to Issues that are
already well-formed.

## Workflow

### Step 1: Capture the rough intent

Take the user's input as the raw *What*. Do **not** ask them to rewrite it or expand it
themselves — capturing intent cheaply is the whole point. If the input is a single line,
that is fine.

If repository context is unclear, establish it:

```bash
gh repo view --json nameWithOwner
```

### Step 2: Classify

Infer the Issue type to guide the Done definition and label. Keep it lightweight — one
signal is enough.

| Signal in the intent | Type | Label | Done tends to look like |
|---|---|---|---|
| broken, error, crash, regression | Bug fix | `bug` | a failing case now passes / reproduces no longer |
| add, support, new, want | Feature | `feature` | new behavior is exercised by a test |
| clean up, restructure, extract, rename | Refactor | `refactor` | behavior unchanged, tests still green |
| doc, readme, explain | Docs | `docs` | the doc reflects current code |

### Step 3: Propose the missing structure

This is the core of the skill. From the rough intent, **draft** the following and present
it for the user to approve or edit. The user's job shrinks from *writing* to *approving*.

- **Done (完了条件)** — 1–3 conditions, each phrased so a machine or a fresh reviewer can
  judge it. Prefer conditions that map onto an existing test, lint, type check, or spec
  assertion. This becomes the contract that `gh-issue-planner` plans against and that the
  post-implementation review checks for *consistency* (did the implementation match the
  declared Done?).
- **Out of scope (触らない範囲)** — the single highest-leverage field. List what must not
  change, what boundaries must not be crossed, and any "works but kills reusability"
  traps (e.g. do not break an existing provider/abstraction layer). This is what lets the
  planner-stage review reject a wrong *direction* before any code is written.
- **Design constraints (設計方針, optional)** — non-functional intent the author holds but
  rarely writes down: reusability/horizontal-deployment expectations, layering rules,
  performance or security posture. Leave empty if none; when present it sharpens the
  planner's direction review.

Present the draft in the user's language:

```
## <proposed title>

### やること (What)
<the user's rough intent, lightly tidied — not expanded>

### 完了条件 (Done)
- <machine-checkable condition 1>
- <condition 2, if any>

### 触らない範囲 (Out of scope)
- <what must not change / boundaries to preserve>

### 設計方針 (Design constraints) — optional
- <non-functional intent, or omit this section>

---
提案です。このまま起票して良いですか？ 修正があれば指定してください。
(Proposal — file as-is, or tell me what to change.)
```

### Step 4: Confirm

- **Never create the Issue without explicit user approval.**
- If a field is genuinely ambiguous, ask **one** focused question — do not interrogate.
- If the user says the Done condition can't be machine-checked, keep it but flag it: an
  Issue whose Done is only human-judgable should stay human-verified downstream (do not
  let it be auto-resolved). Note this in the Issue body.
- Apply edits and re-present only if the change was substantial.

### Step 5: Ensure the label exists

`gh issue create --label` fails if the label does not exist in the repository. Check
first and create if missing (same approach as `report-to-issues` Phase 5):

```bash
gh label list --json name | jq -r '.[].name'
gh label create "<label>" --color "<hex>"
```

| Label | Color |
|---|---|
| `bug` | `#d73a4a` |
| `feature` | `#a2eeef` |
| `refactor` | `#cfd3d7` |
| `docs` | `#0075ca` |

### Step 6: Create the Issue

After approval, create the Issue. Embed the marker comment so `gh-issue-planner` can
recognize a pre-scoped Issue.

```bash
gh issue create \
  --title "<title>" \
  --label "<type-label>" \
  --body "$(cat <<'EOF'
## やること

<what>

## 完了条件

- <done 1>
- <done 2>

## 触らない範囲

- <out of scope>

## 設計方針

- <design constraints, or: なし>

---
<!-- gh-issue-drafter:scoped-issue -->
*Generated by `gh-issue-drafter` — Done/Out-of-scope/constraints were author-approved. Use `gh-issue-planner` to produce the response plan.*
EOF
)"
```

Check the exit code. On failure, report the error to the user instead of retrying blindly.

Report the created Issue number and URL back to the user, and offer the handoff:

> Issue #<n> を起票しました。続けて `gh-issue-planner` で対応方針を立てますか？

## Key Principles

- **Fill gaps, don't add ceremony.** The author writes a loose *What*; the skill supplies
  Done / Out-of-scope / constraints. Never push writing work back onto the author.
- **Done must be checkable.** A Done condition that can't be judged by a test, a check, or
  a fresh reviewer is a weak contract. Prefer conditions that map onto existing CI checks.
- **Out of scope is the highest-leverage field.** Most hand-written Issues omit it, and
  its absence is what lets an agent quietly cross boundaries. Always propose one.
- **Approval, not authorship.** The user approves or edits a draft — this keeps their
  input cost at roughly the same 30 seconds as writing a rough Issue by hand.
- **Never file without confirmation.** Consistent with `gh-issue-planner` and
  `report-to-issues`: no side effects before the user says yes.
- **Stay in your lane.** No investigation, no plan, no code. Hand off to
  `gh-issue-planner`.
