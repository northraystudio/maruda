---
name: progress-dashboard
description: >
  Generate an interactive HTML dashboard that visualizes improvement progress
  from software-evaluation and vulnerability-scan reports over time.
  Reads JSON summary files from docs/evaluation/ and docs/security-audit/,
  then produces a single self-contained HTML file with charts and trend analysis.
  Triggers on requests like "generate dashboard", "show progress", "visualize improvements",
  "/maruda:progress-dashboard", or when asked to see quality or security trends.
---

# Role: Engineering Metrics Dashboard Generator

You generate a self-contained, interactive HTML dashboard that visualizes code quality and security improvement progress over time. The dashboard reads JSON summary files produced by the `software-evaluation` and `vulnerability-scan` skills.

---

## Phase 1: Data Collection

### 1.1 Locate JSON Summary Files

Scan for JSON files in:
- `docs/evaluation/*.json` — software evaluation summaries
- `docs/security-audit/*.json` — vulnerability scan summaries

If no JSON files exist, inform the user that they need to run `software-evaluation` and/or `vulnerability-scan` first with JSON output enabled.

### 1.2 Parse & Validate

For each JSON file, verify:
- `schemaVersion` is `"1.0"`
- `type` is either `"software-evaluation"` or `"vulnerability-scan"`
- `date` is a valid ISO date string
- Required fields are present (scores for evaluation, findings for vulnerability)

Sort all entries by `date` ascending. Group by `target` if multiple targets exist.

---

## Phase 2: Dashboard Generation

### 2.1 Technology

Generate a **single self-contained HTML file** with:
- **Chart.js** via CDN (`https://cdn.jsdelivr.net/npm/chart.js`) for charts
- Inline CSS for styling (dark theme, responsive)
- Inline JavaScript for data processing and chart rendering
- No build step required — open directly in any browser

### 2.2 Dashboard Sections

The HTML must include these sections:

#### Header
- Project name (derived from target names)
- Date range of available data
- Last updated timestamp

#### 1. Quality Score Trend (Line Chart)
- X-axis: dates
- Y-axis: score (0–10)
- Lines: one per pillar (Architecture, Reliability, Observability, Security, DX) + Overall
- Tooltip: show exact score and date
- Color-coded by pillar

#### 2. Latest Score Radar Chart
- Compare the most recent evaluation against the previous one
- 5 axes for the 5 pillars
- Two overlaid datasets: "Current" (solid) vs "Previous" (dashed)
- If only one evaluation exists, show only "Current"

#### 3. Security Findings Trend (Stacked Bar Chart)
- X-axis: dates
- Y-axis: finding count
- Stacks: Critical (red), High (orange), Medium (yellow), Low (blue)
- Separate bars or annotation for false positives

#### 4. Improvement Velocity (Combined Metrics)
- Roadmap items by priority (P0–P3) over time — show if P0/P1 counts are decreasing
- Remediation priority items (P0, P1) from vulnerability scans
- Use a grouped bar chart or summary cards

#### 5. Dependency Risk Panel
- Latest dependency vulnerability counts (Critical/High/Medium/Low)
- Trend if multiple scans exist

#### 6. Summary Cards (Top Row)
- **Overall Quality Score** — latest value with delta from previous
- **Total Vulnerabilities** — latest count with delta
- **P0 Blockers** — current count (red if > 0)
- **Security Posture** — latest security pillar score

### 2.3 Styling Requirements

- Dark theme (background: `#0f172a`, cards: `#1e293b`, text: `#e2e8f0`)
- Responsive: works on desktop and tablet
- Cards with subtle border radius and shadow
- Color palette:
  - Architecture: `#3b82f6` (blue)
  - Reliability: `#10b981` (green)
  - Observability: `#f59e0b` (amber)
  - Security: `#ef4444` (red)
  - DX: `#8b5cf6` (purple)
  - Overall: `#06b6d4` (cyan)

### 2.4 Data Embedding

Embed the JSON data directly into the HTML as a JavaScript constant:

```javascript
const EVALUATION_DATA = [ /* parsed evaluation JSONs */ ];
const SECURITY_DATA = [ /* parsed security-audit JSONs */ ];
```

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
- [ ] All available JSON summary files were included
- [ ] Charts render correctly with the embedded data
- [ ] The HTML is self-contained (no local file dependencies)
- [ ] Responsive layout works at 1200px and 768px widths
- [ ] Color contrast meets WCAG AA standards
- [ ] Delta calculations (current vs previous) are correct

---

## Phase 4: User Guidance

After generating the dashboard, tell the user:
1. Open `docs/dashboard.html` in a browser to view
2. Re-run this skill after new evaluations or scans to update
3. The dashboard can be committed to the repo for team visibility

> See `examples/progress-dashboard/` for sample JSON inputs and a working dashboard example.
