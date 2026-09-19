# 0005. The repository root is both the plugin and its marketplace; pinning is a tag

- Status: Accepted
- Date: 2026-09-19
- Issue: #4

## Context

Claude Code installs plugins from a marketplace: a repository holding
`.claude-plugin/marketplace.json`, whose entries point at plugin directories.
A plugin is a directory holding `.claude-plugin/plugin.json`.

maruda is a single plugin, and `harness/` must ship with it so that
`/maruda:setup` can run the `setup.sh` from the same version as the skills that
run the interview. Two layouts were possible: the repository root as the plugin
with the marketplace beside it, or a `plugins/maruda/` subdirectory.

Version pinning constrained the choice. Reading the plugin documentation and the
installed marketplaces on disk:

- a **plugin** source accepts `ref` (branch or tag) and `sha`, and `sha` wins when
  both are given;
- a **marketplace** source accepts `ref` only — **not** `sha`;
- `extraKnownMarketplaces` and `enabledPlugins` in `settings.json` do **not**
  auto-install. The first makes a marketplace known, the second marks a plugin
  enabled, and each user still runs `/plugin install` once.

A plugin entry that pins its own repository by `sha` is also circular: the SHA
does not exist until the commit that would contain it has been made.

## Decision

The repository root is the plugin (`.claude-plugin/plugin.json`) and its own
marketplace (`.claude-plugin/marketplace.json`), with the single entry using
`"source": "./"`. `harness/` ships inside it — the plugin cache holds the whole
repository and preserves executable bits, so `setup.sh` runs from the cache.

Version pinning is expressed as the **marketplace ref**, a release tag, in the
consumer's `settings.json`. `setup.sh --plugin` writes that (`--plugin-ref <tag>`,
default `main`), merging into whatever is already there.

`obra/superpowers` uses the same root-is-the-plugin layout, and also keeps a
second, non-plugin distribution channel alive.

## Consequences

- One repository, one version: the skills, `harness/scripts/setup.sh` and the
  templates in a plugin install are always the same commit. That is the whole
  reason `harness/` is in the plugin.
- Pinning is tag-granular, not commit-granular, because marketplace sources
  reject `sha`. A release therefore has to be a tag, and moving a tag silently
  changes what users install — so tags are immutable by convention.
- `--plugin` cannot finish the install on the user's behalf. The flag records
  intent for everyone who clones the repository; the final checklist prints the
  `/plugin install maruda@northraystudio` line, and the README repeats it.
- `npx skills add` keeps working against the same directories, so agents other
  than Claude Code are not cut off.
- Adding a second plugin later means moving this one into `plugins/<name>/` and
  changing its `source`, which breaks nothing for existing users beyond a
  re-install.
