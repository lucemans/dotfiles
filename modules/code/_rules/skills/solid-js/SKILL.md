---
name: solid-js
description: SolidJS application conventions. Use only when the project uses solid-js, solid-start, or @tanstack/solid-router; apply when reading, reviewing, or changing Solid TSX/JSX, routes, queries, or Vite configuration.
paths:
  - "**/*.{tsx,jsx}"
  - "**/vite.config.{ts,js,mts,mjs}"
  - "**/routes/**/*"
---

# SolidJS Guidelines

Apply the global operating policy and the TypeScript skill first. This skill adds Solid-specific guidance; it does not relax type safety, dependency approval, testing, or scope rules.

Use this skill only after confirming the project uses Solid. Do not introduce Solid, SolidStart, or a listed library into a project that does not already use it without approval.

## Reactivity

- Components execute once. Read signals with `signal()` in JSX, memos, effects, or other tracked scopes; do not expect top-level component code to rerun.
- Use `createSignal` for independent local values and `createStore` only for nested mutable client state. Keep ownership local and derive values instead of synchronizing duplicate state.
- Use `createMemo` for derived reactive values. Do not use `createEffect` to calculate derived state or write one signal from another when a memo expresses the relationship.
- Use `createEffect` only to synchronize with an external system. Keep effects synchronous, register teardown with `onCleanup`, and use `onMount` for one-time client initialization.
- Do not destructure reactive `props` or access them outside a tracked scope when the value must update. Use `splitProps`, `mergeProps`, access `props.property`, or a memo as appropriate.
- Use context for stable cross-tree capabilities, not as a catch-all mutable global store.

## Components

- Prefer focused arrow-function components with explicit prop types. Use `Component` only when its component typing is helpful.
- Use `<Show>`, `<Switch>`, and `<Match>` for conditional UI. Render collections with `<For>` for referentially keyed items and `<Index>` for stable positional items.
- Put pending UI behind `<Suspense>` and failures behind a nearby `<ErrorBoundary>`. Provide accessible loading, empty, and error states.
- Preserve native HTML semantics, keyboard behavior, visible focus, labels, and accessible names. Use real buttons for actions and links for navigation.
- Keep DOM references local. Use callback refs when lifecycle work is required, and clean up listeners, observers, timers, and subscriptions.

## Server State And APIs

- Prefer `@tanstack/solid-query` for remote server state when it is available. Use stable, domain-specific query keys and expose typed, normalized domain values instead of raw transport responses.
- Model writes with mutations and invalidate or update the relevant query cache after success. Do not maintain a second signal or store copy of query data without a concrete offline or optimistic-update need.
- When the project has generated `openapi-hooks`, use its operation-specific hooks and types for OpenAPI-backed requests. Do not hand-write endpoint strings, duplicate API schemas, or cast transport data around the generated client.
- Validate untrusted route, API, and browser input at the boundary. Keep typed domain conversion close to that boundary.

## Routing

- Prefer the Solid adapter for TanStack Router (`@tanstack/solid-router`) when it is installed. Follow the repository's generated-route and Vite-plugin setup; do not hand-edit generated route artifacts.
- Use typed route parameters and validated search parameters. Keep shareable, URL-owned state in the search parameters rather than duplicating it in local signals.
- Navigate with the router's typed `Link` and navigation APIs. Use route loaders and query prefetching deliberately; avoid duplicate fetching between loaders and components.

## Vite And Styling

- Preserve the existing Vite and Solid plugin configuration. Use `import.meta.env` for client environment values, and never expose secrets through Vite-prefixed variables.
- When Tailwind CSS is configured, use the existing design tokens, responsive variants, and component conventions. Prefer small reusable components over repeated, divergent utility-class blocks.
- Use the project's existing `clsx` or `classnames` package to compose conditional classes. Do not add both packages or build custom class-concatenation helpers.
- Keep presentation state in class names and semantic attributes. Avoid imperative DOM class manipulation except when integrating an external library.

## Dependencies And Verification

- Prefer the project's installed tooling. Ask before adding or upgrading Solid, Vite, Tailwind CSS, TanStack, OpenAPI, or class-name dependencies.
- Run the focused type check, lint, and relevant tests after changes. For interaction changes, verify loading, error, keyboard, and navigation behavior in the running application when practical.
