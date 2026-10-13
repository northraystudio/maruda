# Go rules (generic)

Language-level rules aligned with the evaluation pillars (see
`coding-principles.md` for tags). Stack-specific conventions (framework,
ORM/sqlc, folder layout) belong in your own project rules once the stack is
decided — do not guess them here.

- Wrap errors with context: `fmt.Errorf("loading config %q: %w", path, err)`;
  classify with `errors.Is` / `errors.As`. Never discard with `_ = err`. [REL]
- `context.Context` is the first parameter and propagates through every
  layer — never stored in a struct, never dropped. [REL]
- No `panic` in library code; `recover` only at the process/request boundary
  (middleware). [REL]
- Structured logging with `log/slog`; attach request-scoped attributes
  (trace id, operation) once and pass the logger down. [OBS]
- Define interfaces on the consumer side, and only when a second
  implementation exists (test fakes count). [ARC]
- Prefer package-by-feature over premature layer trees; keep `cmd/` thin —
  wiring only. [ARC]
- No global mutable state; inject dependencies explicitly. [ARC][DX]
- Every goroutine has an owner: `errgroup`/`sync.WaitGroup` plus ctx
  cancellation. No fire-and-forget `go func()`. [REL]
- SQL is parameterized via the driver — never `fmt.Sprintf` into a query. [SEC]
- Decode/validate input at the handler boundary into typed structs; the
  domain layer receives valid values only. [SEC][ARC]
- Never map privilege or ownership fields (`Role`, `IsAdmin`, `UserID`,
  `OwnerID`, etc.) directly from request bodies. Determine them server-side
  from the authenticated principal. [SEC]
- Table-driven tests; keep them `-race`-clean (CI runs `go test -race`). [DX]
