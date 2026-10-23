---
name: solid-js
description: SolidJS application conventions. Use only when the project uses solid-js, solid-start, or @tanstack/solid-router; apply when reading, reviewing, or changing Solid TSX/JSX, routes, queries, or Vite configuration.
---

# SolidJS Guidelines

First apply the global operating policy and the TypeScript skill. This skill adds guidance for Solid. It does not change the rules for types, dependencies, testing, or scope.

Use this skill only after you confirm that the project uses Solid. Do not add Solid, SolidStart, or a library in this skill to a project that does not already use it. Ask for approval first.

## Reactivity

- Components execute one time. Read signals with `signal()` in JSX, memos, effects, or other tracked scopes. Do not expect top-level component code to run again.
- Use `createSignal` for independent local values. Use `createStore` only for nested mutable client state. Keep ownership local. Derive values instead of making duplicate state consistent.
- Use `createMemo` for derived reactive values. Do not use `createEffect` to calculate derived state or to write one signal from another if a memo can show the relationship.
- Use `createEffect` only to synchronize with an external system. Keep effects synchronous. Use `onCleanup` to register teardown. Use `onMount` for one-time client initialization.
- Do not destructure reactive `props`. Do not access them outside a tracked scope if the value must update. Use `splitProps`, `mergeProps`, `props.property`, or a memo as appropriate.
- Use context for stable cross-tree capabilities. Do not use context as a catch-all mutable global store.

## Components

- Use small arrow-function components with explicit prop types. Use `Component` only when its component typing is useful.
- Use `<Show>`, `<Switch>`, and `<Match>` for conditional UI. Use `<For>` for collections with referentially keyed items. Use `<Index>` for stable positional items.
- Put pending UI behind `<Suspense>`. Put failures behind a nearby `<ErrorBoundary>`. Provide loading, empty, and error states that are accessible.
- Keep native HTML semantics, keyboard behavior, visible focus, labels, and accessible names. Use real buttons for actions. Use links for navigation.
- Keep DOM references local. Use callback refs when you need lifecycle work. Clean up listeners, observers, timers, and subscriptions.
- If `@kobalte/core` is installed, use its accessible primitives for dialogs, popovers, menus, tooltips, and other interactive UI. Do not write custom implementations for these components.

## Server State and APIs

- Use `@tanstack/solid-query` for remote server state if it is available. Use stable, domain-specific query keys. Give typed, normalized domain values. Do not return raw transport responses.
- Model writes with mutations. After success, invalidate or update the relevant query cache. Do not keep a second signal or store copy of query data without a clear need for offline or optimistic updates.
- If the project has generated `openapi-hooks`, use its operation-specific hooks and types for OpenAPI-backed requests. Do not write endpoint strings by hand. Do not duplicate API schemas. Do not cast transport data around the generated client.
- Validate untrusted route, API, and browser input at the boundary. Keep typed domain conversion close to that boundary.

## Routing

- Use the Solid adapter for TanStack Router (`@tanstack/solid-router`) if it is installed. Follow the repository setup for generated routes and Vite plugins. Do not edit generated route artifacts by hand.
- Use typed route parameters and validated search parameters. Keep shareable, URL-owned state in the search parameters. Do not duplicate it in local signals.
- Navigate with the router typed `Link` and navigation APIs. Use route loaders and query prefetching with purpose. Do not make duplicate fetches in loaders and components.

## Vite and Styling

- Keep the existing Vite and Solid plugin configuration as it is.
- Use `import.meta.env` for client environment values. Do not expose secrets through Vite-prefixed variables.
- If Tailwind CSS is configured, use the existing design tokens, responsive variants, and component conventions. Use small reusable components. Do not make repeated, divergent utility-class blocks.
- Use the project `clsx` or `classnames` package to put together conditional classes. Do not make class names with template literals. Do not write custom class-concatenation helpers. If neither package is installed, ask before you add one.
- Keep presentation state in class names and semantic attributes. Do not manipulate DOM classes with imperative code except when you integrate an external library.

## Dependencies and Verification

- Use the tooling that the project already has.
- Ask before you add or upgrade Solid, Vite, Tailwind CSS, Kobalte, TanStack, OpenAPI, or class-name dependencies.
- After changes, run the type check, lint, and relevant tests. For interaction changes, verify loading, error, keyboard, and navigation behavior in the running application when practical.
