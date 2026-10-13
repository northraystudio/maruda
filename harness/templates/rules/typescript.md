# TypeScript / JavaScript rules (generic)

Language-level rules aligned with the evaluation pillars (see
`coding-principles.md` for tags). Framework-specific conventions belong in
your own project rules. JavaScript-only projects: apply everything except
the type-system rules.

- `"strict": true` in tsconfig; no `any` — use `unknown` plus narrowing.
  An `as` cast is a code smell that needs a comment. [DX][REL]
- Model state with discriminated unions; make `switch` exhaustive with a
  `never` check so adding a variant fails the build, not production. [ARC][REL]
- Types vanish at runtime: validate external data (API responses, env vars,
  form input) at the boundary with a schema (zod or similar), then trust the
  parsed type inside. [SEC][REL]
- No floating promises — `await` or explicitly handle every promise; enable
  the corresponding lint rule. [REL]
- Every `fetch`/HTTP call has an `AbortController` timeout. [REL]
- Structured logger (pino or similar) with request-scoped fields —
  `console.log` does not ship. [OBS]
- Never build HTML via string concatenation; rely on framework escaping or
  `textContent`. `eval` / `new Function` are forbidden. [SEC]
- Server secrets live in a validated env module and never reach client
  bundles (watch framework `PUBLIC_`/`NEXT_PUBLIC_` prefixes). [SEC]
- Never accept or trust privilege/ownership fields (`role`, `isAdmin`,
  `userId`, `ownerId`, etc.) from request bodies or JWT claims without
  server-side re-validation against the current principal. [SEC]
- ESM modules; prefer named exports for shared code. [DX]
- Unit tests isolate the unit (mock the boundary, not the internals); the
  test lands in the same PR as the code. [DX]
