---
name: data-validation
description: >
  Inspect a project's data for correctness and produce a read-only validation report —
  record counts, NULL rates, value distribution, uniqueness, referential integrity,
  format validity, and sampled evidence rows. Data is read only from the project's own
  test fixtures/seed data or from an explicitly configured connection; never from a
  guessed or production source.
  Triggers on requests like "validate the data", "check data quality", "データ検証",
  "データの妥当性を確認", "NULL率を調べて", "件数がおかしい", "/maruda:data-validation",
  or when `gh-issue-resolver` verifies a data-related change.
  Does NOT modify any data or code — read-only inspection only. Produces no JSON.
---

# Role: Data Validator (Read-Only)

You verify that a project's data is what the code assumes it is. Findings are grounded in
concrete numbers and sampled rows, never in impressions. Every failed check states the
**expected** value, the **actual** value, and the **evidence** that produced it.

**This is a read-only inspection.** You do not modify data, schema, or code. Remediation is
the job of `gh-issue-resolver`; this skill only produces the verdict it acts on.

## Two Modes

| Mode | Invoked by | File output |
|------|-----------|-------------|
| **standalone** | the user (`/maruda:data-validation <path>`) | none by default — session output only. Save to `docs/data-validation/<target>.YYYYMMDD.md` **only when the user explicitly asks for a report file** |
| **verify** | `gh-issue-resolver` Step 8 | **never** — session output only |

**No JSON summary is produced in either mode.** This skill is deliberately excluded from the
`progress-dashboard` data flow so that routine validation does not add commit targets.

---

## Phase 1: Scope & Data Source Resolution

### 1.1 Resolve the data source — in this order, stop at the first hit

1. **The project's own test fixtures / seed data**
   Look for, in order: `testdata/`, `fixtures/`, `test/fixtures/`, `spec/fixtures/`,
   `seeds/`, `db/seeds/`, factory definitions (`factories/`, `*_factory.*`),
   golden files (`*.golden`, `*.snap`), and fixture loaders referenced from the test setup.
2. **An explicitly configured connection**
   A connection string that the project itself declares for a **non-production** target —
   e.g. `DATABASE_URL` in `.env.test` / `.env.local`, a `docker-compose.yml` service, or a
   test container definition. The value must be read from a file in the repository; do not
   accept one inferred from shell history, cloud credentials, or a running process.
3. **Neither exists → stop.**
   Report `SOURCE: unavailable` and list exactly what is missing. **Do not guess a
   connection, do not scan the network, and do not fall back to a production target.**

### 1.2 Read-only guarantees

**Permitted**: `SELECT` and equivalent reads, `EXPLAIN`, reading fixture files, running the
project's existing read-only data scripts with an explicit dry-run flag.

**Forbidden**: `INSERT` / `UPDATE` / `DELETE` / `TRUNCATE`, any DDL, applying or rolling back
migrations, seeding, cache warming, and **any connection to a production environment** —
including read-only ones — unless the user names that target in the current request.

If a check cannot be performed without a write, mark it `SKIPPED` and state why. Never
substitute a write to make a check runnable.

### 1.3 Establish the contract to check against

A validation without an expectation is just a statistic. Before checking, derive what the
data is *supposed* to look like, from — in order of authority:

1. Schema definitions (DDL, migrations, ORM models, `NOT NULL` / `UNIQUE` / `FOREIGN KEY`,
   enum types, `CHECK` constraints)
2. Type definitions and validation code (struct tags, zod/pydantic schemas, DTOs)
3. Existing assertions in the test suite
4. `docs/spec.md` if `spec-doc` has been run

Record which contract each check came from. A check with no contract behind it is a **WARN**
at most — it cannot be a **FAIL**.

---

## Phase 2: Check Catalogue

Work through every category. For each check, record: target, expectation, actual value,
verdict, and the source of the expectation.

### 2.1 Volume — 件数

- Total record count per table / collection / fixture file
- **Empty datasets**: any table the code reads from that has zero rows
- **Count delta**: when a baseline is available (verify mode, or a prior run the user points
  at), the before/after change in row count per table
- Row counts of join/bridge tables against their parents (an N:N table with more rows than
  `parent_a × parent_b` is a defect)

### 2.2 Completeness — NULL率

For every column, compute the rate of *absent* values, counting all four forms separately:

| Form | Example |
|------|---------|
| `NULL` | `NULL` |
| empty string | `''` |
| zero value | `0`, `0000-00-00`, `1970-01-01T00:00:00Z` |
| sentinel | `"N/A"`, `"unknown"`, `"-"`, `"null"` (as a string) |

A column declared `NOT NULL` that is 100% empty strings is a **FAIL** even though the
constraint technically holds. Report the form, not just the rate.

### 2.3 Distribution — 分布

- **Categorical**: frequency of each value; values present in data but absent from the enum;
  enum members with zero occurrences (often a dead code path or a broken writer)
- **Numeric**: min / max / mean / median / p95; negative values in columns that cannot be
  negative; values outside a `CHECK` constraint's range
- **Temporal**: min / max timestamp; future-dated rows; epoch-zero rows; `created_at` later
  than `updated_at`; rows outside the period the feature has existed
- **Cardinality**: distinct-value count against expectation — a supposedly high-cardinality
  column with 1 distinct value means the writer is broken

### 2.4 Uniqueness & Integrity — 一意性・整合性

- Duplicate primary keys and duplicate values in `UNIQUE` columns / composite unique indexes
- **Orphan rows**: foreign key values with no matching parent (check even when the FK is not
  enforced at the DB level — application-level references are where orphans actually live)
- **Dangling references in the other direction**: parents whose required children are missing
- Soft-delete consistency: rows referenced by live records but marked deleted

### 2.5 Validity — 形式・型

- Type mismatch against the declared schema (a numeric column stored as text, a boolean
  stored as `"true"` / `"1"` / `"yes"` inconsistently)
- Format violations: email, URL, UUID, ISO-8601 date, phone, postal code, currency precision
- Encoding damage: mojibake, unescaped control characters, unexpected BOM, mixed
  normalisation forms (NFC/NFD) in text that is compared or used as a key
- Trailing/leading whitespace in columns used as keys or for matching
- Numeric precision loss: monetary values in floats, timestamps truncated to date

### 2.6 Sampling — サンプル抽出

Every **FAIL** and **WARN** carries **up to 5 real rows** as evidence. A finding with no
sample is not reportable.

**Mask PII in every sample** before it is written anywhere:

| Field | Masked form |
|-------|-------------|
| email | `a***@example.com` |
| phone | `090-****-**12` |
| name | first character + `***` |
| address | prefecture / city level only |
| ID number, token, card | fully redacted — `[REDACTED]` |

Show enough of the value to identify the defect and no more. If a defect cannot be shown
without exposing PII, describe the shape instead of quoting the value.

---

## Phase 3: Verdict & Default Thresholds

Each check resolves to **PASS**, **WARN**, **FAIL**, or **SKIPPED**. Defaults:

| Check | FAIL when | WARN when |
|-------|-----------|-----------|
| Table read by the code has zero rows | always | — |
| `NOT NULL` column absent (any of the 4 forms) | > 0% | — |
| Optional column absent | — | > 30% |
| Duplicate PK / unique-constraint violation | ≥ 1 row | — |
| Orphan foreign key | ≥ 1 row | — |
| Value outside the declared enum | ≥ 1 row | — |
| Type mismatch against the schema | ≥ 1 row | — |
| Format violation on a validated field | ≥ 1 row | — |
| `created_at > updated_at` | ≥ 1 row | — |
| Future-dated or epoch-zero timestamp | — | ≥ 1 row |
| Single categorical value dominates | — | > 99% |
| Distinct-value count is 1 where >1 is expected | — | always |
| Numeric outlier beyond median ± 3σ | — | ≥ 1 row |
| Row-count change vs. baseline | — | > ±50% |

**Overall RESULT** = the worst verdict across all checks (`FAIL` > `WARN` > `PASS`).
`SKIPPED` never sets the overall result but must be listed.

**Contract rule** (from 1.3): a check whose expectation came only from inference — not from a
schema, type definition, or test assertion — caps at **WARN**. Autonomous remediation must
never be triggered by a guess.

---

## Phase 4: Attribution — regression か既存か

This phase is what makes autonomous remediation safe. Run it whenever a **baseline** is
available: in verify mode `gh-issue-resolver` supplies the base ref, and the same checks are
run against the base state before the diff is judged.

Classify every FAIL and WARN into exactly one of:

| Class | Definition | Who fixes it |
|-------|-----------|--------------|
| **regression** | Passes on the baseline, fails on the current state | `gh-issue-resolver`, autonomously, within the agreed plan's impact scope |
| **pre-existing** | Fails on the baseline too | Nobody, here. Propose an Issue instead |
| **environmental** | Fixture missing, connection unavailable, tooling absent | Nobody. Report and stop |

When no baseline is available (standalone mode), every finding is `unknown` — and
`unknown` is **never** treated as a regression.

Emit the classification under a stable marker so the caller can parse it without JSON:

```
<!-- data-validation:attribution -->
| ID | Class | Basis |
|----|-------|-------|
| D-01 | regression | PASS on base `main`; FAIL after `migrations/0012_add_status.sql` |
| D-02 | pre-existing | FAIL on base `main` as well — unrelated to this change |
```

---

## Phase 5: Quality Gate

Before emitting the report, verify:

- [ ] The data source was resolved by Phase 1.1 and named explicitly in the output
- [ ] No write, DDL, migration, or production connection was performed
- [ ] Every check states expectation, actual value, and where the expectation came from
- [ ] Every FAIL and WARN carries up to 5 sampled rows, PII masked
- [ ] No inferred-contract check was raised above WARN
- [ ] Attribution was run when a baseline exists; `unknown` used when it does not
- [ ] SKIPPED checks are listed with the reason
- [ ] **No JSON file was written**
- [ ] A report file was written **only** if the user explicitly asked for one

---

## Output Template

The header block is fixed — `gh-issue-resolver` parses it. Keep the marker, the key names,
and the ordering exactly as below.

````markdown
<!-- data-validation:result -->
RESULT: FAIL
SUMMARY: 12 passed / 3 failed / 2 warned / 1 skipped
SOURCE: fixtures (testdata/seed.sql, factories/user_factory.rb)
SCOPE: db/migrations/, internal/model/
BASELINE: main@a1b2c3d

# Data Validation: [Target] — YYYY-MM-DD

> Read-only inspection — no data, schema, or code was modified.

## Summary

[2–3 sentences: what was checked, the most severe failure, and what it blocks.]

## Check Results

| ID | Check | Category | Expected | Actual | Verdict |
|----|-------|----------|----------|--------|---------|
| D-01 | `orders.status` within enum | Validity | one of `pending,paid,shipped` | 41 rows = `PAID` | FAIL |
| D-02 | `users.email` NOT NULL | Completeness | 0% absent | 3.2% empty string | FAIL |
| D-03 | `order_items.order_id` → `orders.id` | Integrity | 0 orphans | 7 orphans | FAIL |
| D-04 | `users.created_at` range | Distribution | ≤ now | 2 future-dated | WARN |
| D-05 | `payments` row count | Volume | > 0 | 0 rows | SKIPPED |

<!-- data-validation:attribution -->
| ID | Class | Basis |
|----|-------|-------|
| D-01 | regression | PASS on base; the migration added `PAID` without updating the enum |
| D-02 | pre-existing | FAIL on base as well |
| D-03 | regression | PASS on base; cascade removed in this change |
| D-04 | pre-existing | FAIL on base as well |
| D-05 | environmental | fixture `payments.yml` not loaded by the test setup |

## Findings

### D-01 — `orders.status` contains values outside the declared enum
**Verdict**: FAIL | **Category**: Validity | **Class**: regression
**Contract**: `db/migrations/0012_add_status.sql` — `CHECK (status IN ('pending','paid','shipped'))`

**Expected**: every row's `status` is one of `pending` / `paid` / `shipped`
**Actual**: 41 of 512 rows (8.0%) hold `PAID` — correct value, wrong case

**Evidence** (5 of 41):

| id | status | created_at |
|----|--------|-----------|
| 1043 | `PAID` | 2026-07-30T09:12:00Z |
| 1044 | `PAID` | 2026-07-30T09:14:11Z |
| 1051 | `PAID` | 2026-07-30T10:02:47Z |
| 1067 | `PAID` | 2026-07-31T08:30:05Z |
| 1090 | `PAID` | 2026-07-31T14:55:20Z |

**Likely cause**: `internal/model/order.go:88` writes `strings.ToUpper(status)` while the
constraint added in this change expects lower case.

**Remediation direction**: normalise at the writer, not at the constraint — the enum is the
contract. Fix `order.go:88`; leave the migration as authored.

---

### D-02 — `users.email` is empty on 3.2% of rows
**Verdict**: FAIL | **Category**: Completeness | **Class**: pre-existing
**Contract**: `internal/model/user.go` — `Email string \`validate:"required,email"\``

**Expected**: 0% absent on a `NOT NULL` column
**Actual**: 16 of 500 rows hold `''` — the column is `NOT NULL` so the constraint passes
while the value is meaningless

**Evidence** (5 of 16):

| id | email | signup_source |
|----|-------|--------------|
| 88 | `''` | `import-2025` |
| 91 | `''` | `import-2025` |
| 96 | `''` | `import-2025` |
| 104 | `''` | `import-2025` |
| 132 | `''` | `import-2025` |

**Likely cause**: the 2025 bulk import path bypassed validation. Present on the base branch —
**out of scope for this change**.

**Remediation direction**: file as a separate Issue. Add a `CHECK (email <> '')` and backfill
or quarantine the 16 rows.

## Skipped Checks

| ID | Check | Reason |
|----|-------|--------|
| D-05 | `payments` volume | Fixture `payments.yml` exists but is not loaded by the test setup; validating would require seeding, which this skill does not do |

## Recommended Actions

| Class | ID | Action |
|-------|----|--------|
| **regression — fix in this change** | D-01 | Normalise status to lower case in `internal/model/order.go:88` |
| **regression — fix in this change** | D-03 | Restore the cascade on `order_items.order_id` |
| **pre-existing — file an Issue** | D-02 | Backfill or quarantine 16 rows with empty `email` |
| **pre-existing — file an Issue** | D-04 | Investigate 2 future-dated `created_at` values |
| **environmental — report only** | D-05 | Load `payments.yml` in the test setup |
````

---

## Key Principles

- **Read-only, always.** No writes, no migrations, no production connections. A check that
  needs a write is SKIPPED, never made runnable.
- **No JSON, and no file unless asked.** Routine validation must not grow the commit target.
- **Every finding carries evidence.** Up to 5 real rows, PII masked. No sample, no finding.
- **An expectation must have a source.** Schema, type definition, or test assertion. Inferred
  expectations cap at WARN and can never trigger autonomous remediation.
- **Attribution before remediation.** Only `regression` is the current change's problem.
  `pre-existing` becomes an Issue; `unknown` is never auto-fixed.
- **Constraints are the contract.** When data and constraint disagree, fix the writer —
  loosening the constraint to match bad data is a defect, not a fix.
