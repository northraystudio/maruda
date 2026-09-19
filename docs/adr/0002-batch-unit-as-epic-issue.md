# 0002. A batch is an Epic Issue with sub-issues, and carries no child PRs

- Status: Accepted
- Date: 2026-09-19
- Issue: #3

## Context

Grouping several Issues into one release needs a durable, machine-readable
answer to "which Issues are in this batch, and in what state?" — the batch flow
re-reads that state every time it starts. Three representations were considered:
an Epic Issue with sub-issues, a Milestone, or nothing but the branch name plus a
marker comment on each member Issue.

GitHub's sub-issues and issue-dependency APIs are reachable from the `gh` CLI
(verified on gh 2.95.0):

```
gh api repos/{owner}/{repo}/issues/{n}/sub_issues
gh api repos/{owner}/{repo}/issues/{n}/dependencies/blocked_by
```

Writes take the issue's **id**, not its number.

Separately, the batch flow had to decide whether each Issue gets its own PR into
the integration branch, or whether the integration branch simply collects one
commit per Issue.

## Decision

A batch is an **Epic Issue holding its members as sub-issues**, on the branch
`epic/<n>-<slug>`. The Epic is created by `yds-gh-batch-runner`, not by hand.

Within a batch, **no child PRs are created**. Each Issue lands on the integration
branch as its own commit (`<type>(#<n>): ...`). CI and review happen once, on the
single PR from the integration branch to the integration target.

Dependencies between Issues are recorded with GitHub's `blocked_by`, and can be
added or changed at any time; the batch flow re-reads them at start.

## Consequences

- "Which Issues are in this batch" is one API call, and survives independently of
  branch names, comment text and local state. Per-Issue verification records have
  a natural home on the Epic.
- The Epic is machine-generated, so the overhead a human sees for a batch of
  small fixes is a title and a link — the objection that "an Epic is heavy for
  small fixes" applies to hand-written Epics, not generated ones.
- Skipping child PRs keeps the PR count at one per release and avoids running CI
  against a branch that branch protection cannot cover. The trade-off is that
  per-Issue review granularity is lost; the per-Issue commit boundary is what
  remains, so commits must stay Issue-scoped.
- Milestones keep their release meaning and are not overloaded as batch markers.
- CI must run for PRs whose base is an `epic/**` or Issue branch, otherwise the
  stacked flow has no verification at all.
