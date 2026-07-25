---
name: typescript
description: TypeScript and JavaScript implementation conventions. Use when reading, reviewing, or changing TS, TSX, JS, JSX, MTS, CTS, MJS, or CJS files.
paths:
  - "**/*.{ts,tsx,js,jsx,mts,cts,mjs,cjs}"
---

# V3X TypeScript and JavaScript Guidelines

Write strictly typed, function-oriented code with small, cohesive modules, explicit boundaries, and minimal conceptual overhead.

## Source of truth

Follow, in order:

1. Repository-local instructions
2. ESLint, formatter, compiler, and test configuration
3. Current maintained implementation
4. These guidelines
5. Legacy code and examples

Do not copy weak typing, stale suppressions, or obsolete patterns from older files.

## Scope

* Make the smallest complete change.
* Preserve existing user changes.
* Do not refactor, reformat, rename, or fix unrelated code.
* Ask before adding dependencies, updating lockfiles, changing development environments, running migrations, or making broad changes.
* For material unstated choices, present concise options and indicate the option most consistent with these preferences.

## Architecture

* Organize code into cohesive domains and subdomains.
* Keep core logic separate from UI, transport, storage, and framework adapters.
* Keep adapters thin and orchestration explicit.
* Prefer concrete code over generic frameworks.
* Abstract only around a stable, existing responsibility.

## Functions and classes

* Never use the `function` keyword.
* Use arrow functions, factories, closures, hooks, and plain objects.
* Prefer narrow capability-based APIs.
* Keep mutable state private to the closure or module that owns it.
* Do not use classes except for errors or rare framework-required cases such as Web Components.

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

Use manual dependency injection through factory parameters. Avoid DI containers and decorator-based injection.

## TypeScript

* Everything should be typed where practical.
* Never use `any` in code or types we control.
* Use `unknown` for untrusted input, then validate or narrow it immediately.
* External-library `any` is acceptable only as a narrow last-resort boundary and must not propagate inward.
* Prefer `type` over `interface`.
* Never create `types.ts` or similar collective type dumps.
* Keep types beside the domain or behavior that owns them.
* Use discriminated unions and make invalid states unrepresentable where practical.
* Assertions are acceptable only after validation or when TypeScript cannot express a proven invariant.
* Avoid non-null assertions.
* Allow `@ts-expect-error` only in intentionally failing type tests.
* Never use `@ts-ignore` or double assertions.

## Errors

Use a local dependency-free Result type for expected failures.

```ts
type Result<Value, Failure> =
    | { ok: true; value: Value }
    | { ok: false; error: Failure };
```

Return Results for recoverable failures. Throw only for exceptional failures, violated invariants, programmer errors, or framework-required paths.

## Validation

Validate public and untrusted input at runtime.

* Prefer Zod for structured validation.
* Use plain JavaScript checks when validation is simple or Zod is unavailable.
* Do not redundantly validate values produced by trusted typed code.

## Naming

* Never use bare `id` unless an external contract requires it.
* Prefer `userId`, `postId`, `messageId`, and similar domain-specific names.
* Include units in measurable names: `timeoutMs`, `sizeBytes`, `intervalSeconds`, `amountWei`.
* Boolean names should usually begin with `is`, `has`, `can`, or `should`.
* Use camelCase internally.
* Use snake_case only for external protocols, database fields, wire formats, or compatibility-sensitive names.

## Control flow

* Prefer early returns.
* Avoid nested ternaries.
* Prefer `async`/`await` over long promise chains.
* Use intermediate variables when they clarify domain meaning or sequencing.
* Keep mutation local.
* Prefer readable imperative code over clever compression.

## Lifecycles

For sockets, streams, timers, subscriptions, workers, and similar resources:

* Make setup and teardown explicit.
* Handle cancellation, timeouts, retries, and repeated invocation.
* Clear timers and detach listeners.
* Prevent duplicate cleanup.
* Distinguish intentional shutdown from failure where relevant.

## Frontend

* Use arrow-function components.
* `FC` in React and `Component` in Solid are acceptable.
* Prefer conventional separated folders such as `components`, `hooks`, `pages`, `routes`, `api`, and `utils`.
* Use effects only for external synchronization.
* Derive state instead of duplicating it.
* TanStack Query hooks should expose typed, normalized domain values rather than raw transport responses.

## Imports and exports

* Use named exports.
* Avoid default exports unless a framework or tool requires one.
* Avoid barrel files except deliberate public package entry points.
* Avoid `export *`.
* Respect package export maps and repository import conventions.

## Compatibility

Treat public APIs, exports, event names, wire formats, schemas, URLs, and externally visible state values as compatibility boundaries.

Do not change them accidentally. When changing them intentionally, consider validation, parsing, serialization, migration, tests, documentation, and release impact.

## Testing and verification

* Choose unit, integration, end-to-end, or type tests based on the behavior.
* Not every bug fix requires a regression test.
* Test observable behavior rather than private implementation details.
* Run relevant formatting, linting, type checking, and tests.
* Do not weaken tests or lint rules to make code pass.

## Completion

Before finishing:

* Confirm the change is correctly scoped.
* Confirm no unrelated refactor or dependency change occurred.
* Confirm there is no uncontrolled `any`, suppression, or unjustified assertion.
* Confirm names are domain-specific and include units where useful.
* Confirm lifecycle and failure paths are handled.
* Remove temporary logging, dead code, and stale comments.
* Review the diff for the smallest complete solution.
