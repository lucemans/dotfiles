---
name: typescript
description: TypeScript and JavaScript implementation conventions. Use when reading, reviewing, or changing TS, TSX, JS, JSX, MTS, CTS, MJS, or CJS files.
paths:
  - "**/*.{ts,tsx,js,jsx,mts,cts,mjs,cjs}"
---

# V3X TypeScript and JavaScript Guidelines

Write code that is strictly typed and function-oriented. Make modules small and cohesive. Make boundaries explicit. Keep conceptual overhead to a minimum.

## Source of Truth

Follow these sources in this order:

1. Repository-local instructions
2. ESLint, formatter, compiler, and test configuration
3. Current maintained implementation
4. These guidelines
5. Legacy code and examples

Do not copy weak typing, old suppressions, or obsolete patterns from older files.

## Scope

- Make the smallest complete change.
- Keep existing user changes as they are.
- Do not refactor, reformat, rename, or fix unrelated code.
- Ask before you add dependencies, update lockfiles, change development environments, run migrations, or make broad changes.
- For material choices that are not stated, give concise options. Show which option is most consistent with these preferences.

## Architecture

- Organize code into cohesive domains and subdomains.
- Keep core logic separate from UI, transport, storage, and framework adapters.
- Keep adapters thin. Make orchestration explicit.
- Use concrete code instead of generic frameworks.
- Abstract only around a stable, existing responsibility.

## Functions and Classes

- Do not use the `function` keyword.
- Use arrow functions, factories, closures, hooks, and plain objects.
- Use narrow, capability-based APIs.
- Keep mutable state private to the closure or module that owns it.
- Do not use classes except for errors or rare framework-required cases such as Web Components.

```ts
type Connection = {
    open: () => void;
    close: () => void;
    isConnected: () => boolean;
};

const createConnection = (): Connection => {
    let isConnected = false;

    return {
        open: () => {
            isConnected = true;
        },
        close: () => {
            isConnected = false;
        },
        isConnected: () => isConnected,
    };
};
```

- Use manual dependency injection through factory parameters. Do not use DI containers and decorator-based injection.

## TypeScript

- Everything that can have a type should have a type.
- Do not use `any` in code or types that we control.
- Use `unknown` for untrusted input. Then validate it or narrow it immediately.
- External-library `any` is acceptable only as a narrow last-resort boundary. It must not go inward.
- Use `type` instead of `interface`.
- Do not create `types.ts` or similar collective type dumps.
- Keep types beside the domain or behavior that owns them.
- Use discriminated unions. Make invalid states unrepresentable where practical.
- Assertions are acceptable only after validation or if TypeScript cannot express a proven invariant.
- Do not use non-null assertions.
- Use `@ts-expect-error` only in type tests that are supposed to fail.
- Do not use `@ts-ignore` or double assertions.

## Errors

Use a local Result type that has no dependencies for expected failures.

```ts
type Result<Value, Failure> =
    | { ok: true; value: Value }
    | { ok: false; error: Failure };
```

Return Results for failures from which the code can recover. Throw only for exceptional failures, violated invariants, programmer errors, or framework-required paths.

## Validation

Validate public and untrusted input at runtime.

- Use Zod for structured validation.
- Use plain JavaScript checks if validation is simple or Zod is not available.
- Do not validate values that trusted typed code produces. This is redundant.

## Naming

- Do not use bare `id` unless an external contract requires it.
- Use `userId`, `postId`, `messageId`, and similar domain-specific names.
- Include units in measurable names: `timeoutMs`, `sizeBytes`, `intervalSeconds`, `amountWei`.
- Boolean names should usually start with `is`, `has`, `can`, or `should`.
- Use camelCase internally.
- Use snake_case only for external protocols, database fields, wire formats, or compatibility-sensitive names.

## Control Flow

- Return early when possible.
- Do not nest ternaries.
- Use `async`/`await` instead of long promise chains.
- Use intermediate variables if they make the domain meaning or sequencing clear.
- Keep mutation local.
- Use readable imperative code. Do not compress code to make it clever.

## Lifecycles

For sockets, streams, timers, subscriptions, workers, and similar resources:

- Make setup and teardown explicit.
- Handle cancellation, timeouts, retries, and repeated invocation.
- Clear timers and detach listeners.
- Prevent duplicate cleanup.
- Distinguish between intentional shutdown and failure when relevant.

## Frontend

- Use arrow-function components.
- `FC` in React and `Component` in Solid are acceptable.
- Use conventional separated folders such as `components`, `hooks`, `pages`, `routes`, `api`, and `utils`.
- Use effects only for external synchronization.
- Derive state. Do not duplicate it.
- TanStack Query hooks should give typed, normalized domain values. They should not give raw transport responses.

## Imports and Exports

- Use named exports.
- Do not use default exports unless a framework or tool requires one.
- Do not use barrel files except as deliberate public package entry points.
- Do not use `export *`.
- Respect package export maps and repository import conventions.

## Compatibility

Treat public APIs, exports, event names, wire formats, schemas, URLs, and externally visible state values as compatibility boundaries.

Do not change them by accident. If you change them with purpose, consider validation, parsing, serialization, migration, tests, documentation, and release impact.

## Testing and Verification

- Choose unit, integration, end-to-end, or type tests based on the behavior.
- Not every bug fix needs a regression test.
- Test observable behavior. Do not test private implementation details.
- Run the relevant formatting, linting, type checking, and tests.
- Do not make tests or lint rules weaker so that code passes.

## Completion

Before you finish:

- Confirm that the change scope is correct.
- Confirm that no unrelated refactor or dependency change occurred.
- Confirm that there is no uncontrolled `any`, suppression, or unjustified assertion.
- Confirm that names are domain-specific and include units where useful.
- Confirm that lifecycle and failure paths are handled.
- Remove temporary logging, dead code, and stale comments.
- Look at the diff. Make sure it is the smallest complete solution.
