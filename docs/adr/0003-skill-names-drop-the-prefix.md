# 0003. Skill directories carry no prefix; the plugin namespace does the grouping

- Status: Accepted
- Date: 2026-09-19
- Issue: #4

## Context

Every skill was named `yds-<thing>` (`yds-spec-doc`, `yds-gh-issue-planner`, …).
The prefix was added deliberately so the skills would sit together in Claude
Code's flat, alphabetical command list — the commit that introduced it says as
much. It was never about collision avoidance.

Shipping the repository as a Claude Code plugin changes the arithmetic. A
plugin's commands are namespaced by the plugin name, and the leaf of that name is
the skill's **directory** name. Agent Skills also requires a skill's frontmatter
`name` to equal its directory name, so there is exactly one string to choose and
it serves both distribution channels:

| directory | plugin command | `npx skills add` command |
| --- | --- | --- |
| `spec-doc` | `/maruda:spec-doc` | `/spec-doc` |
| `maruda-spec-doc` | `/maruda:maruda-spec-doc` | `/maruda-spec-doc` |

Keeping a prefix therefore buys grouping for `npx skills add` users at the cost
of stuttering in the plugin, which is now the primary channel.

## Decision

Drop the prefix. Directories and frontmatter names are the bare skill names
(`spec-doc`, `software-evaluation`, `gh-issue-planner`, …), and grouping is the
plugin namespace's job: `/maruda:<skill>`.

This is the same trade-off `obra/superpowers` makes — unprefixed skill
directories, grouping supplied by the `superpowers:` namespace, and a second
distribution channel that lives without it.

## Consequences

- Plugin users get `/maruda:spec-doc`. The namespace is the grouping, and it is
  stronger than a prefix because it also disambiguates.
- `npx skills add` users get `/spec-doc` with no grouping, and a real chance of
  colliding with another collection that also ships a `spec-doc`. We accept that:
  the cost lands on the secondary channel, and the user can rename the directory
  on their side.
- Projects installed under the old names must delete `.claude/skills/yds-*` and
  reinstall. Leaving both registers every skill twice. The README carries the
  migration note.
- Handoff markers (`<!-- gh-issue-planner:agreed-plan -->` etc.) and the JSON
  summary `type` values are unaffected — they never carried the prefix, and they
  are embedded in existing Issues, PR comments and dashboard data.
- Renaming again later is cheap in this repository and expensive for every
  installed project, so the name is now a contract.
