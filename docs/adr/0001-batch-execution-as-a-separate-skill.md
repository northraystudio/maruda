# 0001. Batch execution lives in its own skill, not in the resolver

- Status: Accepted
- Date: 2026-09-19
- Issue: #3

## Context

Running several Issues as one unit — fix together, verify together, release
together — needs work the single-Issue resolver does not do: choosing the flow,
ordering Issues by their dependencies, verifying the integration branch as a
whole, and opening one PR to the integration target.

`yds-gh-issue-resolver` carries invariants that make it safe to run
autonomously: it fixes **regression** findings only, for at most 3 iterations,
and never leaves the agreed plan's impact scope. Those invariants are defined
against a single Issue and a single baseline (the integration target).

Two placements were considered:

1. Extend `yds-gh-issue-resolver` with a batch mode.
2. Add a new orchestrating skill that delegates per-Issue work.

## Decision

Add a new skill, **`yds-gh-batch-runner`**, that owns the batch flow and
delegates each Issue's implementation to the existing resolver contract.

`yds-gh-issue-resolver` gains exactly one addition: an explicit **base ref**
(defaulting to the integration target, and set to the dependency's branch in the
stacked flow). Its regression/iteration/scope invariants are unchanged.

## Consequences

- The resolver's autonomy boundary stays readable: one Issue, one plan, one
  baseline. A reader does not have to work out which rules apply in which mode.
- Batch-level concerns (ordering, whole-branch verification, the single
  integration PR) have one home, and batch regressions are defined against the
  integration target rather than against each Issue's own base.
- The cost is one more skill to discover and register. The cycle grows from
  "Plan → Resolve" to "Plan → Resolve *or* Batch-run", so both README and the
  cycle rules must name when each applies.
- A batch that turns out to be a single Issue is just the individual flow; the
  runner is not on the path for it.
