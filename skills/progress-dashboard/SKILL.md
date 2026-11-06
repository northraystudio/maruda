---
name: progress-dashboard
description: >
  Generate an interactive HTML dashboard that visualizes improvement progress
  from software-evaluation, vulnerability-scan and dependency-audit reports over time.
  Reads JSON summary files from docs/evaluation/, docs/security-audit/ and docs/dependency-audit/,
  then produces a single self-contained HTML file with Quality, SAST and Dependency Audit tabs.
  Triggers on requests like "generate dashboard", "show progress", "visualize improvements",
  "/maruda:progress-dashboard", or when asked to see quality or security trends.
---

# Role: Engineering Metrics Dashboard Generator

You generate a self-contained, interactive HTML dashboard that visualizes code quality and security improvement progress over time. The dashboard reads JSON summary files produced by the `software-evaluation`, `vulnerability-scan` and `dependency-audit` skills, and shows each on its own tab: **Quality**, **SAST** and **Dependency Audit**.

---

## Phase 1: Data Collection

### 1.1 Locate JSON Summary Files

Scan for JSON files in:
- `docs/evaluation/*.json` — software evaluation summaries
- `docs/security-audit/*.json` — vulnerability scan summaries
- `docs/dependency-audit/*.json` — dependency audit summaries

If no JSON files exist, inform the user that they need to run `software-evaluation`, `vulnerability-scan` and/or `dependency-audit` first with JSON output enabled.

### 1.2 Parse, Validate & Route by `type`

Route every file by its `type` field, not by its directory:

| `type` | Data constant | Tab |
|--------|---------------|-----|
| `software-evaluation` | `EVALUATION_DATA` | Quality |
| `vulnerability-scan` | `SECURITY_DATA` | SAST (and the Dependency Audit back-fill, 2.3) |
| `dependency-audit` | `DEPENDENCY_DATA` | Dependency Audit |

For each file, verify:
- `schemaVersion` is `"1.0"`
- `type` is one of the three above
- `date` is a valid ISO date string
- Required fields are present (scores for evaluation, findings for vulnerability scan, `status` for dependency audit)

A file whose `type` is unknown (or missing) is **skipped, not fatal**: leave it out of the data
constants, list its file name in `SKIPPED_FILES`, and tell the user which files were skipped.
One unreadable summary must never stop the whole dashboard.

Sort all entries by `date` ascending. Group by `target` if multiple targets exist.

---

## Phase 2: Dashboard Generation

### 2.1 Technology

Generate a **single self-contained HTML file** with:
- **Chart.js** via CDN (`https://cdn.jsdelivr.net/npm/chart.js`) for charts
- Inline CSS for styling (dark theme, responsive)
- Inline JavaScript for data processing, tab switching and chart rendering
- No build step required — open directly in any browser

### 2.2 Layout

#### Header (shared)
- Project name (derived from target names)
- Date range of available data, across all three sources
- Last updated timestamp

#### Tabs
Three tabs — **Quality**, **SAST**, **Dependency Audit** — following the WAI-ARIA tabs pattern:
`role="tablist"` / `tab` / `tabpanel`, `aria-selected`, `aria-controls`, a roving `tabindex`,
Left/Right/Home/End to move between tabs, and a visible focus outline. Quality is selected
first.

Draw a tab's charts the first time it is shown, not on page load: Chart.js measures a hidden
canvas as zero-width.

#### Quality tab (`software-evaluation`)
- **Summary cards** — Overall Quality (delta from previous), P0 Blockers (red if > 0), Security Score
- **Quality Score Trend** (line) — one line per pillar (Architecture, Reliability, Observability,
  Security, DX) + Overall, y 0–10, color-coded by pillar
- **Latest vs Previous** (radar) — 5 pillar axes, "Current" solid vs "Previous" dashed; only
  "Current" when a single evaluation exists
- **Roadmap Progress** — evaluation roadmap P0 / P1 over time

#### SAST tab (`vulnerability-scan`)
- **Summary cards** — Total Vulnerabilities (delta), Remediation P0 (red if > 0), False Positives
- **Security Findings Trend** (stacked bar) — Critical (red), High (orange), Medium (yellow), Low (blue)
- **Remediation Progress** — scan remediation P0 / P1 over time
- **Latest Findings** — `topFindings` of the latest scan

#### Dependency Audit tab (`dependency-audit`, back-filled from `vulnerability-scan`)
- **Summary cards** — Dependency Vulnerabilities (latest total, delta), Latest Audit Status
  (status, `notRunReason`, coverage, source), Upgrades P0 / P1, Scanner (version, pinned, DB date)
- **Dependency Vulnerabilities Trend** (stacked bar) — Critical / High / Medium / Low / Unknown,
  one bar per date from the series in 2.3, the source in the tooltip
- **Dependency Remediation** — upgrade P0 / P1 from dependency-audit summaries

### 2.3 The dependency series

The Dependency Audit trend is one series across the split, built per **target and date** —
two targets scanned on the same day are two points, never one (when there is more than one
target, each label names its target):

1. A `dependency-audit` summary for that target and date wins.
   - `complete` → its `vulnerabilities` counts.
   - `partial` → its counts, labelled "(partial)" — they cover scanned targets only.
   - `not-run` (or any other status, or no `vulnerabilities`) → no counts, labelled "(not run)"
     or "(unavailable)".
2. Otherwise, the `dependencies` field of that target and date's `vulnerability-scan` summary, so the history
   from before the split stays on the chart. Those summaries have no `unknown` severity: leave
   it empty, not 0. A scan without `dependencies` (its audit was partial or did not run) has no
   counts, labelled "(unavailable)".

A date without counts is a **labelled gap** — the bar is empty and the axis label says why. Never
draw it as 0, never leave it unlabelled, and never fall back to an older audit's counts for the
latest card (say "Last counted: <date>" instead): any of those reads as a clean audit.

The cards follow the same rule:
- **Latest Audit Status**, Upgrades and Scanner come from the newest `dependency-audit` summary
  itself, not from the merged series — a later back-filled scan must not hide an audit that did
  not run.
- A **delta** compares a point with the one immediately before it **for the same target**, and only when both have counts
  and neither is partial. Across a gap or a coverage change, show no delta: a drop there may be
  missing coverage, not an improvement.

### 2.4 Styling Requirements

- Dark theme (background: `#0f172a`, cards: `#1e293b`, text: `#e2e8f0`)
- Responsive: works on desktop and tablet; the tab bar scrolls horizontally when narrow
- Cards with subtle border radius and shadow
- Color palette:
  - Architecture: `#3b82f6` (blue)
  - Reliability: `#10b981` (green)
  - Observability: `#f59e0b` (amber)
  - Security: `#ef4444` (red)
  - DX: `#8b5cf6` (purple)
  - Overall: `#06b6d4` (cyan)
  - Severity: Critical `#dc2626`, High `#f97316`, Medium `#eab308`, Low `#3b82f6`, Unknown `#64748b`

### 2.5 Data Embedding

Embed the JSON data directly into the HTML as JavaScript constants:

```javascript
const EVALUATION_DATA = [ /* software-evaluation JSONs */ ];
const SECURITY_DATA = [ /* vulnerability-scan JSONs */ ];
const DEPENDENCY_DATA = [ /* dependency-audit JSONs */ ];
const SKIPPED_FILES = [ /* file names skipped for an unknown type */ ];
```

Summaries are data, not markup. Embed them as JSON with every `<` written as `\u003c`, so a string
containing `</script>` cannot end the script block, and put every string from them into the
page with `textContent` — never `innerHTML`.

This makes the HTML fully self-contained and portable.

---

## Phase 3: Output

### 3.1 File Output

Save the generated dashboard as:
```
docs/dashboard.html
```

### 3.2 Quality Gate

Before finalizing, verify:
- [ ] All available JSON summary files were included, routed by `type`; skipped files are listed
- [ ] Each tab renders its charts when opened, with the embedded data
- [ ] The Dependency Audit trend runs across the split without a break, and every date without counts is a labelled gap, not 0
- [ ] Tabs work with the keyboard (arrows, Home, End) and show focus
- [ ] The HTML is self-contained (no local file dependencies)
- [ ] No summary string is inserted as HTML
- [ ] Responsive layout works at 1200px and 768px widths
- [ ] Color contrast meets WCAG AA standards
- [ ] Delta calculations (current vs previous) are correct

---

## Phase 4: User Guidance

After generating the dashboard, tell the user:
1. Open `docs/dashboard.html` in a browser to view
2. Re-run this skill after new evaluations, scans or dependency audits to update
3. The dashboard can be committed to the repo for team visibility

> See `examples/progress-dashboard/` for sample JSON inputs and a working dashboard example.
