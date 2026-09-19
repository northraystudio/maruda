# 0004. Hooks stay in the installer; the plugin ships none

- Status: Accepted
- Date: 2026-09-19
- Issue: #4

## Context

A Claude Code plugin can carry its own `hooks/hooks.json`, and the hooks then
activate with the plugin. That is tempting: the harness installs four hooks
(format-on-write, dangerous-bash guard, SessionStart context, Stop nudge), and
moving them into the plugin would delete the whole `settings.json` merge path
from `setup.sh` — the one part of the installer that needs `jq` and that has to
preserve a user's existing hook entries.

Two things argue against it.

The harness's component model is **one interview answer, one flag, one file**:
`--no-format-hook`, `--no-bash-guard`, `--no-guidance-hooks`. A plugin's hooks
arrive as a block. Whether a single hook from a plugin can be disabled per
project is undocumented, and a plugin installed at user scope runs its hooks in
every project — including repositories that never asked for this harness.

The hooks are also not plugin-shaped. They exist to enforce *this project's*
rails, they sit next to `CLAUDE.md`, `.claude/rules/` and the CI templates that
the plugin cannot write anyway, and a teammate who clones the repository should
get them from the repository, not from a plugin they may not have installed.

## Decision

Hooks remain `setup.sh`'s responsibility, written to `.claude/hooks/` and
registered by merging into `.claude/settings.json`. The plugin ships skills and
the bundled `harness/`, and no `hooks/hooks.json`.

## Consequences

- Per-hook opt-out keeps working, and the interview's component-to-flag mapping
  stays intact.
- The `settings.json` merge stays, with its `jq` dependency and its "existing
  entries are preserved" guarantee. The installer's regression tests cover it.
- Hooks are committed with the repository, so teammates get them on clone whether
  or not they use the plugin — which is also what makes the harness work for
  agents other than Claude Code.
- Whether a plugin's hooks can be disabled per project stops being a question we
  need answered.
- If hooks ever do move into the plugin, the migration is one-way for installed
  projects: the old `.claude/hooks/` files would have to be removed by hand, since
  the installer never deletes what it did not write.
