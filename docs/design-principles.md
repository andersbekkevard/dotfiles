# Design Principles

Living document. Updated as we learn by building. Every coding agent should read this before starting a new project or making architectural decisions.

## Stack Defaults

**For tools, daemons, CLIs, and internal infrastructure:**
- **Runtime:** Bun. Not Node, not Deno. Bun is the runtime, package manager, test runner, and bundler.
- **Language:** TypeScript with maximum strictness.
- **Why Bun:** Built-in SQLite (`bun:sqlite`), built-in test runner (`bun:test`), native TypeScript, fast startup, zero config. One binary does everything.

**For complex applications or performance-critical code:**
- **Rust** is the alternative. Use when you need: native binaries, extreme performance, FFI, or when Bun/TS isn't suitable.

## TypeScript Rules

- `strict: true` in tsconfig. All compiler options maxed (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, etc.)
- **Zero `any`.** Zero `as` casts. Zero `@ts-ignore`. Zero `@ts-expect-error`.
- If you can't type something safely, redesign it — don't cast.
- Use discriminated unions, branded types, and `satisfies` over `as`.
- Explicit return types on all functions. Explicit parameter types.
- `import type { ... }` for type-only imports.
- Named exports only. No default exports.
- Prefer functions and modules over classes (unless genuinely needed).
- Error handling: use Result types (`{ ok: true, data } | { ok: false, error }`) for expected errors, not thrown exceptions.

## Dependencies

- **Minimize external deps.** We have an army of coding agents — build it ourselves when reasonable.
- **Allowed frameworks:** Hono (HTTP), Zod (validation). These are small, fast, well-typed.
- **Formatting/linting:** Biome. Not ESLint, not Prettier.
- **No logging libraries.** Structured JSON to stderr/files. Simple logger utility per project.
- **No ORM.** Use `bun:sqlite` directly with typed wrappers.
- Every dependency is a liability. Ask: "Can we build this in <1 hour ourselves?"

## Testing Philosophy

- **`bun:test`** only. No Jest, no Vitest.
- Tests live next to source: `foo.ts` → `foo.test.ts`
- Two categories:
  1. **Unit** (`*.test.ts`): Pure logic, real data fixtures (not mocks), fast.
  2. **Integration** (`*.integration.test.ts`): Real files, real SQLite, real HTTP. Guard behind `LIVE_TESTS=1` when hitting external APIs.
- **No mock-only tests for I/O code.** If a module does I/O, it must have integration tests with real I/O.
- Use real data fixtures from actual systems (redacted if needed), committed to `tests/fixtures/`.

## Logging & Debugging

- **Structured JSONL** to files + stderr (for systemd journal).
- Every line: `{"ts":"ISO","level":"info|warn|error|debug","module":"...","msg":"...","data":{...}}`
- Queryable via `jq`, `grep`, or project-specific CLI tools.
- Log directory: `<project>/logs/`
- Rotation: built-in, no external tools.
- **Debug mode** via `LOG_LEVEL=debug` env var.
- **Health endpoint** on HTTP services: uptime, last operation, error counts.
- **Debugging docs** in every project: `docs/debugging.md`

## Project Structure

```
project/
├── CLAUDE.md              # Agent instructions (project-specific rules)
├── README.md              # Human-readable overview
├── package.json           # Bun scripts only
├── tsconfig.json          # Maximum strictness
├── biome.json             # Formatting + linting
├── src/                   # Source code
│   ├── index.ts           # Entry point
│   └── *.test.ts          # Co-located tests
├── tests/fixtures/        # Real data samples
├── docs/                  # Architecture, debugging, testing guides
└── logs/                  # Runtime logs (gitignored)
```


## Git

- Small, focused commits. Conventional: `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`
- Don't commit: node_modules, dist, .env, *.db, logs/

## Decision Record

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-15 | Bun for all TS tooling | Built-in SQLite, test runner, TS support. One tool. |
| 2026-02-15 | Minimize deps, build ourselves | Agent army makes custom code cheap. Deps are liabilities. |
| 2026-02-15 | Structured JSONL logging | Agent-queryable, no external deps, systemd-friendly. |
| 2026-02-15 | Real fixtures over mocks | Tests should prove the code works with actual data. |

---

*This document evolves. When you learn something new about what works or doesn't, add it here.*

