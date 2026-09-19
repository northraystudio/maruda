# 0006. A release is a version bump plus a tag; the version lives in exactly two places

- Status: Accepted
- Date: 2026-09-20
- Issue: #13

## Context

`docs/adr/0005` decided how a plugin version is *pinned* — a marketplace ref, because
marketplace sources reject a `sha`. It never said who raises the version, or when. That
gap surfaced the first time it could: #11's fix reached `main`, and nothing reached the
people running the plugin.

```
$ claude plugin marketplace update northraystudio
✔ Successfully updated marketplace: northraystudio      # the clone is now current
$ claude plugin update maruda
✔ maruda is already at the latest version (0.1.0).      # the install is not
```

An installed plugin lives in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`,
and `plugin update` compares version strings. With the version unchanged, the marketplace
clone and the installed copy drift apart and the update prints success. Nothing is broken
— the old version keeps working — which is exactly why it goes unnoticed. Recovering took
an `uninstall` followed by an `install`.

The version was written in three places: `plugin.json`, the marketplace's
`plugins[0].version`, and `metadata.version`. Measured, not assumed:

| Check | `metadata.version` at `9.9.9`, `plugins[0].version` at `0.1.0` |
|---|---|
| `claude plugin tag --dry-run` | passes |
| `claude plugin validate` | passes |

So the third copy is one nothing reads and nothing checks — a place where drift is
guaranteed to go unseen. Removing it also passes validation.

## Decision

**The version lives in two places**, `.claude-plugin/plugin.json` and the marketplace's
`plugins[0].version`. `metadata.version` is removed and must not come back: a copy no tool
validates is a copy that will drift.

**Raise the version in the same PR as the change.** A PR that alters anything a plugin
user receives — a skill, `harness/`, the manifests — bumps the version. A PR that touches
only what the plugin does not ship, such as this repository's own CI or notes, does not.
Semver, and nothing more prescriptive than that.

**Release with `claude plugin tag`,** never by hand:

```bash
claude plugin tag --dry-run .     # verifies the two versions agree, prints the tag
claude plugin tag --push .        # tags maruda--v<version> and pushes it
```

It refuses to run against a dirty working tree, so the tag always points at the commit
being released. That refusal is the guard; this repository writes no script of its own.

**After merging, confirm the release actually lands:**

```bash
claude plugin marketplace update northraystudio
claude plugin update maruda       # must report the new version, not "already at the latest"
```

## Consequences

- One number, two files, one command that checks they agree. There is no longer a copy
  that can drift unnoticed.
- The check is not a gate. This repository runs no CI on itself, and a missed bump breaks
  nothing — it only delays delivery. `claude plugin tag --dry-run` before tagging catches
  the mismatch at the moment it matters, and `plugin update` reporting "already at the
  latest version" after a release is the signal that a bump was forgotten.
- Tags are immutable by convention, as `0005` already requires for pinning with
  `setup.sh --plugin-ref`. Moving a tag would silently change what pinned users install.
- `npx skills add` users are unaffected: that channel has no version and always resolves
  to the branch.
- Users on a version that was never bumped need `uninstall` then `install`; `plugin
  update` cannot help them. That is the cost of a missed bump, and it falls on users
  rather than on us, which is the argument for bumping in the same PR.
