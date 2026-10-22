# Custom Semgrep rules

`vulnerability-scan` and the generated `security-scan.yml` run Semgrep's
registry rules plus two sets of custom rules, when they exist:

| Set | Where | Who writes it |
|-----|-------|---------------|
| **maruda shared rules** | `skills/vulnerability-scan/rules/` in this repository; `setup.sh` copies them into `.semgrep/maruda/` of the target project | maruda, via PR |
| **Project rules** | `.semgrep/rules/` in the target project | the project — by hand, or through `/maruda:rule-proposer` |

With neither present the scan is exactly the registry scan. Semgrep fails on a
`--config` directory with no rules, so both the skill and the workflow pass
`--config .semgrep` only when it holds a rule file.

## Conventions

- **One rule, one fixture.** Put `<rule-id>.yml` next to `<rule-id>.<ext>`
  (`.ts`, `.py`, `.go`, …). In the fixture, mark lines that must match with
  `// ruleid: <rule-id>` and lines that must not with `// ok: <rule-id>`.
  Check with `semgrep --test .semgrep/rules`.
- **Fixtures are excluded from the scan.** The generated `.semgrepignore`
  lists `.semgrep/`, because fixtures are intentionally vulnerable. That entry
  covers rule fixtures only; never exclude application source to silence a
  rule — fix the rule or use `# nosemgrep: <rule-id>` with a reason.
- **Metadata uses Semgrep's standard `metadata:` block.** No custom format.
  Recommended keys: `category`, `cwe`, `owasp`, `confidence`, `references`.
  Optional, free-form: `endpoints` (the routes the rule guards) and `origin`
  (the finding it was generalized from).
- **Shared rules stay generic.** A rule goes into the shared set only when it
  matches a pattern, not an application's names or values.
- **Validate before committing:** `semgrep --validate --config <file>`.

## Template

[`docs/examples/semgrep-rule.yml`](examples/semgrep-rule.yml) is a complete
rule with every metadata key filled in. Copy it to `.semgrep/rules/`, rename
the `id`, and write its fixture.

## What is not a rule

Authorization gaps and business-logic flaws depend on what an operation is
*supposed* to allow. They are reviewed by hand (`vulnerability-scan` Layer 2),
not forced into a pattern. `rule-proposer` says so and stops for these.
