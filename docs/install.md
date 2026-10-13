# Installing maruda — the details

The [README](../README.md#install) has the short version. This page holds
everything the installer generates, every entry point and flag, how updates
work, and the migration note for projects installed under the old `yds-` names.

- [Entry points](#entry-points)
- [What the full harness generates](#what-the-full-harness-generates)
- [Flags](#flags)
- [Existing files are never overwritten](#existing-files-are-never-overwritten)
- [Gate maturity ladder](#gate-maturity-ladder)
- [Skills only](#skills-only)
- [Update](#update)
- [Migrating from the `yds-` names](#migrating-from-the-yds--names)

## Entry points

| Entry point | When to use |
| --- | --- |
| `curl \| bash` one-liner | Fresh machine / CI / "just drop the files in" (non-interactive, flags required) |
| `harness/scripts/setup.sh` | You already cloned this repo |
| `/maruda:setup` in Claude Code | Decide languages and commands interactively (no auto-detection) |
| `--plugin` | Record the plugin in `.claude/settings.json` so everyone who clones the repo installs the same skills |

```bash
# One-liners
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh \
  | bash -s -- --langs go,typescript --pm pnpm --with-skills     # full
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh \
  | bash -s -- --minimal                                         # rails only

# From a clone
./harness/scripts/setup.sh --target /path/to/your-project --langs python --python-pm uv
```

Prefer inspecting scripts before piping to bash:

```bash
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh -o install.sh
less install.sh && bash install.sh --langs go
```

Supported languages: Go, Python, TypeScript, JavaScript. Run `setup.sh --help`
for all flags. Installer regression tests: `bash harness/tests/run.sh`.

## What the full harness generates

Skills alone give workflows (L1). The full harness adds mechanical guardrails —
format-on-write and dangerous-command hooks, a lean CLAUDE.md, cycle rules,
GitHub Actions CI, and a security scan — so quality is maintained from day one
and the continuous improvement cycle is the default path (L2–L3). L4
(scheduled, automated diagnosis) is deliberately out of scope.

Always (`--minimal` installs only these, minus `CLAUDE.md`):

- `CLAUDE.md` — Stack & commands, the cycle, hard rules (not with `--minimal`;
  fill it in later with `/maruda:setup`)
- `.claude/hooks/` — format-on-write, dangerous-bash guard, SessionStart
  context, Stop nudge
- `.claude/settings.json` — hooks merged into whatever is already there
- `.claude/rules/maruda-cycle.md` — the cycle contract
- `.env.example` and `.gitignore` entries for `.env`

With `--langs` (skipped by `--minimal` and `--no-ci`):

- `.github/workflows/ci.yml` — per-language jobs (Go: go.mod guard / tidy-check
  / build / `test -race` / cached pinned golangci-lint; Node: script preflight
  / frozen-lockfile install / lint / typecheck (TS) / test; Python: ruff /
  pytest). **Strict by design**: a missing lint/typecheck/test script — or zero
  tests — fails the job with an actionable `::error` telling you exactly what
  to add, so verification lands with the first code PR. Both workflows also
  run on direct pushes to the default branch
- `.github/workflows/security-scan.yml` — gitleaks + semgrep gating from day
  one (shift-left), trivy staged as `continue-on-error`, Node
  production-dependency audit
- `.gitleaks.toml` and `.semgrepignore` with a smallest-unit-only allowlist
  policy
- `docs/harness-checklist.md` — the manual steps that turn strict CI green
  (add scripts, first test, commit lockfile, branch protection, promote trivy);
  delete it when done
- `.claude/rules/` — **score-aligned coding principles** (KISS / YAGNI plus the
  five `software-evaluation` pillars inverted into "write it right the first
  time" rules, each tagged with the pillar it scores on; the security rules
  preempt `vulnerability-scan` findings) and per-language best practices
  (`go.md` / `python.md` / `typescript.md`, installed per `--langs`)

With `--pr-agent`:

- `.github/workflows/pr-agent.yml` and `.pr_agent.toml` — advisory AI review
  via [qodo-ai/pr-agent](https://github.com/qodo-ai/pr-agent) (describe /
  review / improve when a PR opens, `/review` on each push, slash commands for
  repository members; action pinned to a release-tag SHA). Opt-in because it
  needs an `OPENAI_KEY` repository secret and API billing. **Never a required
  check**, and it composes with `--no-ci` for projects that already have CI

CI tool and action versions are pinned (no `@latest`); the local format hook
only runs project-installed formatters and never downloads code.

## Flags

`setup.sh --help` is the source of truth; this is the map.

| Flag | Effect |
| --- | --- |
| `--langs LIST` | Required unless `--minimal`. Comma-separated; the first entry is the primary. Never detected |
| `--minimal` | Hooks + settings + rules only, no `CLAUDE.md` and no CI. Fill the stack later with `/maruda:setup` |
| `--target DIR` / `--name NAME` | Install somewhere other than the current directory / project name for `CLAUDE.md` |
| `--branch NAME` / `--integration-branch NAME` | Default branch (`main`) / the branch PRs target and CI gates when releases flow through e.g. `staging` |
| `--default-flow individual\|batch\|stack` | Default flow when several Issues run at once (recorded in `CLAUDE.md`) |
| `--pm pnpm\|npm\|yarn\|bun` / `--python-pm uv\|pip\|poetry` | Package managers used in CI and `CLAUDE.md` commands |
| `--guard-pip` | Add the "use uv, not pip install" bash guard |
| `--no-ci` | Skip the GitHub Actions workflows |
| `--no-format-hook` / `--no-bash-guard` / `--no-guidance-hooks` / `--no-rules` / `--no-env-guard` | Skip one component; `settings.json` is filtered to match |
| `--pr-agent` | Add the advisory PR Agent (composes with `--no-ci`, not with `--minimal`) |
| `--protect` | Apply required status checks via `gh` (needs repo admin on a pushed default branch) |
| `--plugin` / `--plugin-ref REF` | Record the marketplace and plugin in `.claude/settings.json`, optionally pinned to a tag. Mutually exclusive with `--with-skills` |
| `--with-skills` | Also run `npx skills add northraystudio/maruda --skill '*' --agent claude-code -y --copy` |
| `--force` | Overwrite existing files instead of proposing `<file>.new` |

Generated workflows also run for PRs whose base is a batch (`epic/**`) or an
Issue branch (`feat/**`, `fix/**`, `refactor/**`), so batched and stacked work
is verified; push triggers stay on the default and integration branches only.

**Checks gate merges only when branch protection marks them required.** The
installer reports the protection state in its checklist; pass `--protect` to
apply required status checks automatically, or configure them in GitHub
settings. Unconfigured protection is reported as an incomplete state, not a
success.

## Existing files are never overwritten

When an incoming file differs from what you already have, it is written
alongside as `<file>.new` (pacman `.pacnew` style) — review with
`diff <file> <file>.new`, merge what you want, then delete the `.new`.
Identical files clear stale `.new` proposals; `--force` overwrites outright.
`settings.json` is the exception: its hooks are merged automatically (existing
entries preserved). The final checklist lists every proposed file.

## Gate maturity ladder

The defaults are day-one settings. Promote gates as the project matures:

| Stage | When | Action |
| --- | --- | --- |
| **0 — Day one** (default) | Fresh project | gitleaks + semgrep block; trivy informs (`continue-on-error`); CI strict (missing scripts/tests fail) |
| **1 — Deps triaged** | Trivy findings reviewed, unfixable ones in `.trivyignore` with reasons | Delete the `continue-on-error: true` line in `security-scan.yml` — trivy becomes a hard gate |
| **2 — Enforced** | Default branch pushed, repo admin available | `setup.sh --protect` (or GitHub settings) — checks become required status checks, force-push/deletion blocked |
| **3 — Tightened** | Team cadence stable, few false positives | Raise `--audit-level` to `moderate`, add stricter Semgrep rulesets (e.g. `p/cwe-top-25`), consider `strict: true` reviews |

PR Agent (`--pr-agent`) sits outside the ladder on purpose: it is advice, not
a gate, and `--protect` never adds it to the required checks.

## Skills only

### Claude Code plugin (recommended)

```
/plugin marketplace add northraystudio/maruda
/plugin install maruda@northraystudio
```

Every skill arrives namespaced — `/maruda:spec-doc`, `/maruda:setup`,
`/maruda:gh-issue-planner` — so nothing collides with other skill collections,
and the bundled `harness/scripts/setup.sh` is always the same version as the
skills. `/maruda:setup` then installs the harness itself; the plugin cannot
write files into your project, so `CLAUDE.md`, hooks, `settings.json`, rules
and CI stay `setup.sh`'s job.

To pin a release instead of tracking `main`, add the marketplace with a ref:

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "northraystudio": {
      "source": { "source": "github", "repo": "northraystudio/maruda", "ref": "maruda--v0.2.0" }
    }
  },
  "enabledPlugins": { "maruda@northraystudio": true }
}
```

`setup.sh --plugin` writes exactly those two keys for you
(`--plugin-ref maruda--v0.2.0` to pin a tag), merging into whatever is already
in `settings.json`. Note that Claude Code does **not** auto-install from
settings: the keys make the marketplace known and mark the plugin enabled, and
each person still runs `/plugin install maruda@northraystudio` once.

### CLI install (any agent)

```bash
# All skills, non-interactive, copied into .claude/skills/
npx skills add northraystudio/maruda --skill '*' --agent claude-code -y --copy

# One skill
npx skills add northraystudio/maruda --skill spec-doc --agent claude-code -y --copy
```

Running plain `npx skills add northraystudio/maruda` opens an interactive
picker where **nothing is pre-selected** — press Space to select skills before
Enter, or use the flags above. `--copy` copies files instead of symlinking, so
the skills can be committed and shared with your team.

### Manual copy

```bash
cp -r skills/spec-doc .claude/skills/spec-doc   # one
cp -r skills/* .claude/skills/                  # all
```

### Git submodule

```bash
git submodule add https://github.com/northraystudio/maruda.git .claude/maruda
```

Then reference skills from `.claude/maruda/skills/`.

## Update

Auto-update is **off** by default for third-party marketplaces such as this
one, so an installed plugin stays at its version until you update it. First
refresh the marketplace, then the plugin:

```bash
claude plugin marketplace update northraystudio
claude plugin update maruda@northraystudio
```

Inside a session the same steps are in `/plugin`: **Marketplaces** →
`northraystudio` → **Update marketplace**, then **Installed** → `maruda` →
**Update now**. The running session keeps the old skills until you run
`/reload-plugins`; a new session picks up the new version automatically. To
stop doing this by hand, choose **Enable auto-update** for `northraystudio` in
the **Marketplaces** tab.

- **Pinned to a tag?** The update stays on that tag. Point the `ref` (or
  `setup.sh --plugin --plugin-ref`) at the new tag, `maruda--v<version>`,
  instead.
- **"already at the latest version", but `main` has newer changes?** Updates
  are detected by the `version` in `.claude-plugin/plugin.json`, so a change
  merged without a version bump does not reach you (`docs/adr/0006`). Run
  `claude plugin uninstall maruda@northraystudio` and then install it again.
- The harness files that `setup.sh` wrote into your project are not part of
  the plugin; update those by re-running the install command. Changed files
  appear as `<file>.new` for manual merge, nothing is overwritten.

## Migrating from the `yds-` names

The `yds-` prefix is gone. It existed to group the skills in a flat command
list, and the plugin namespace now does that job — `/yds-spec-doc` becomes
`/maruda:spec-doc` under the plugin, or `/spec-doc` via `npx skills add`.

- In projects installed before the rename, **delete the old
  `.claude/skills/yds-*` directories** and reinstall; leaving them registers
  every skill twice.
- The cycle rule moved with it: `.claude/rules/dev-skills-cycle.md` is replaced
  by `.claude/rules/maruda-cycle.md`, and `setup.sh` reports the stale file
  rather than deleting something it did not write.
- The submodule path is now `.claude/maruda`
  (`git mv .claude/dev-skills .claude/maruda` if you use one).
- Handoff markers (`<!-- gh-issue-planner:agreed-plan -->` etc.) and JSON
  summary `type` values keep the legacy names, so existing issues and
  dashboard data remain compatible.

The repository itself moved from `ymd38/dev-skills` to `northraystudio/maruda`
on 2026-09-20. GitHub redirects the old URLs, so one-liners and clones that
still point at the old address keep working and projects already installed
need no action. New links should use the new address.
