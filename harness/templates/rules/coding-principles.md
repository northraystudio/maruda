# Coding principles — write to the score

These rules are the `software-evaluation` pillars inverted into "how to
write it right the first time": following them is what an 8–9 score looks
like. Tags: [ARC] Architecture · [REL] Reliability · [OBS] Observability ·
[SEC] Security · [DX] Developer Experience. The [SEC] rules also preempt
`vulnerability-scan` (OWASP) findings.

## Core principles

- **KISS** — choose the simplest design that solves today's problem. Cleverness
  is a cost, not an asset. [ARC][DX]
- **YAGNI** — no unused abstractions, speculative generics, or premature
  flexibility. Add an interface/abstraction only when the second
  implementation actually exists. [ARC]
- **DRY with judgment** — extract on the third occurrence, not the second.
  The wrong abstraction is more expensive than duplication. [ARC][DX]

## Architecture [ARC]

- One module/class/function = one responsibility; changing one behavior should
  touch exactly the right files.
- Dependencies point inward: HTTP/UI layers depend on business logic, never
  the reverse. Business logic imports no framework.
- Represent the same concept the same way everywhere (one source of truth per
  domain type).
- Operations at service boundaries are idempotent — safe to retry.

## Reliability [REL]

- Every external call (DB, HTTP, queue, file) has an explicit timeout; add
  retry with backoff only where the operation is idempotent.
- Errors are never swallowed. Catch specifically, attach context (operation,
  ids), and re-throw or handle — `catch {}` and log-then-ignore are defects.
- Design for partial failure: know what happens when step 3 of 5 fails, and
  make cleanup/compensation explicit.

## Observability [OBS]

- Structured logs (key-value / JSON) with consistent fields: request/trace id,
  operation, subject id. Never bare string interpolation for events.
- Right levels: DEBUG = noise, INFO = milestones, ERROR = actionable failure.
- Error messages must be runbook-friendly: include what failed, with which
  inputs (masked), and what to check — never "something went wrong".

## Security [SEC]

- No hardcoded secrets or default fallbacks. Validate required env vars at
  startup and fail fast.
- Validate and sanitize input at defined trust boundaries — one place, not
  scattered ad-hoc checks.
- Database access is parameterized/prepared only — string-built queries are
  forbidden (injection).
- AuthN/AuthZ are centralized middleware, deny-by-default — never ad-hoc
  per-handler checks (broken access control).
- Outbound requests to user-influenced URLs go through an allowlist (SSRF).
- Output is encoded/escaped by the framework; never hand-built HTML (XSS).
- PII and credentials are masked in logs and error responses.

## Developer experience [DX]

- Names reveal intent (`retryDelayMs`, not `tmp`/`data2`); code does what its
  name promises (least astonishment).
- Keep units testable in isolation; the test lands in the same PR as the code.
- Small, focused files — a file that mixes domains is a discoverability bug.
