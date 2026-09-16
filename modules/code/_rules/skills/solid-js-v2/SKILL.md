---
name: solid-js-v2
description: Build, review, and debug Solid 2 (v2/RC) static SPAs, especially Vite apps with Solid Router 2 file routes, typed OpenAPI clients, TanStack Solid Query, or viem/wagmi. Use only after confirming the project uses Solid 2 APIs; do not apply Solid 1 conventions to it.
---

> this file was written by an llm, the contents are a summary of the solid-js-v2 docs at https://v2.solidjs.com/ taken 2026-09-16
> it may contain innaccuracies report to the user when this skill becomes stale and needs updating.

# Solid 2 frontend engineering

Apply the repository instructions and the TypeScript skill first. This skill is for **Solid 2** (`solid-js` v2 / matching v2 packages), whose APIs and async model differ materially from Solid 1. Verify installed package versions and existing router/data setup before changing code. Follow the project’s established libraries; do not add, replace, or upgrade Solid, a router, TanStack Query, OpenAPI tooling, viem, or wagmi without approval.

## Non-negotiable execution model

A Solid component is setup code that normally runs **once**, not a render function that reruns. JSX expressions, memos, and tracked computations update independently and precisely.

- `createSignal<T>(initial)` returns `[read, write]`; call `read()` wherever the current value is needed. Passing `read` to JSX renders a function, not its value.
- Reads in a component body, event handler, `onSettled` callback, `ref` callback, or arbitrary helper are untracked. If the value must stay current, read it in JSX, a `createMemo`, the compute half of `createEffect`, or another tracked scope.
- Write from event handlers. Writes land in a batch after the current synchronous work, so do not set a signal and expect an immediate read on the next line to be new. Derive the next value first; in tests, wait for updates or use `flush()` only outside actions.
- Derive rather than synchronize copies of state. Use a plain function for a cheap, single-reader derivation; use `createMemo` when it is expensive, shared, async, or needs an equality boundary.
- `createEffect(compute, effect)` is specifically an **imperative exit from Solid**. The compute function tracks and returns the external input; the effect runs after the DOM has updated. Use it for storage, analytics, charts, a socket send, or imperative library updates—not fetching, mapping state, setting one signal from another, or handling a click.
- `untrack(() => value())` is intentional opt-out for a one-time snapshot. Do not use it to suppress a reactivity problem.
- Create signals, stores, memos, effects, and custom `createX` primitives in a component body, context provider, or another owned primitive—not in an event handler, ref callback, or module scope. An owner disposes its effects/cleanups when its subtree leaves.
- Register every listener, timer, observer, subscription, and stream teardown with `onCleanup`, or return it from `onSettled`. `onSettled` is client-only one-time setup; it does not track reads.

```tsx
import { createEffect, createMemo, createSignal, onCleanup } from "solid-js";

type Props = { price: number; quantity: number };

const LineTotal = (props: Props) => {
  // Correct: props stay reactive because this is evaluated reactively.
  const total = createMemo(() => props.price * props.quantity);

  // Correct only because document.title is outside Solid.
  createEffect(
    () => total(),
    (amount) => {
      document.title = `$${amount.toFixed(2)}`;
    },
  );

  return <output>${total().toFixed(2)}</output>;
};
```

### Props, children, context, and state ownership

- Props are a reactive proxy. **Never destructure reactive props** (`const { user } = props`) or capture a current prop value in the component body. Read `props.user` in a tracked expression; use `splitProps`, `merge`, `omit`, or a memo if necessary.
- Components have no implicit `children` type. Declare it when a component accepts children (`ParentProps`, `FlowProps`, or an explicit prop) and use the `children` helper only when resolving/inspecting children is actually necessary.
- Keep ephemeral UI state local. Put shareable URL state in the URL, remote API state in its query cache, and stable cross-tree capabilities in context. Context values are created inside a provider, once per browser app—never a module-scope signal/store unless it is deliberately application-global.
- A context without a default should intentionally throw outside its provider; expose a `useX()` function so misuse fails close to the cause.
- Use `createStore` for cohesive, deeply nested local/client state. Its returned proxy is read-only; mutate only through its draft setter. Do not put `Date`, `Map`, class instances, DOM nodes, or a remote-query cache into a store and expect deep tracking.
- For derived collection views use `createProjection`; for a plain snapshot for serialization/non-reactive integrations use `snapshot`.

```tsx
const [form, setForm] = createStore({ name: "", shipping: { postalCode: "" } });
setForm((draft) => {
  draft.shipping.postalCode = nextPostalCode;
});
```

## JSX, UI, lists, and accessibility

- Use real semantic HTML: `<button>` for actions, `<a>`/router links for navigation, a label for every input, visible focus, native keyboard behavior, and accessible pending/error messaging. Prefer installed accessible primitives (for example Kobalte) over handmade dialog/menu/focus management.
- Use `onInput` for immediate text/checkbox updates and read `event.currentTarget`, not a loosely typed `target`.
- Use `<Show when={value} fallback={...}>`; its function child receives an accessor, so call it (`{(user) => user().name}`). Use `<Switch>`/`<Match>` for mutually exclusive cases.
- Use `<For each={items()}>` for normal collections: rows retain identity when the same object remains. Use `<Index>`/`<Repeat>` only when positions are the identity and row slots should remain while values change. Do not use array `.map()` in JSX for dynamic lists or mutate/recreate all rows unnecessarily.
- Give domain objects stable IDs and preserve object identity across refreshes. This prevents focus, input values, and expensive row setup from being destroyed. Window very large lists rather than rendering thousands of nodes.
- Conditional `class` accepts strings, objects, and arrays. Follow the project class utility/design tokens; do not imperatively manipulate classes.
- Use callback `ref`s for element assignment only. They run untracked and without an owner, so do not create effects or cleanups inside them. Establish external widgets once with `onSettled`, update them with `createEffect`, and destroy them in its cleanup.
- Use `createUniqueId()` for label/ARIA IDs that must match SSR hydration. Use `Portal` for layers that must escape clipping; use `lazy()` plus a nearby `<Loading>` boundary for code-split UI.

## Async reactivity and boundaries (Solid 2 names)

Solid 2 reads promise-returning memos and stores as values. It does **not** use the Solid 1 `createResource`/`<Suspense>`/`<ErrorBoundary>` model for new v2 code.

- Make a remote derivation with `createMemo(() => request(reactiveInput()))`, or a fetching store with `createStore(async () => request(), seed)`. Read every reactive input before the first `await`; reads after it are not tracked.
- Put `<Loading fallback={...}>` tightly around the region that reads async data. It catches the not-ready read and shows a fallback. Put `<Errored fallback={(error, reset) => ...}>` at the same product/region boundary to contain failures and offer retry/recovery.
- Boundaries are product decisions: provide an accessible initial loading state, a stable stale/refetch state, empty content, and an actionable error state. Do not wrap an entire route if the header and independent panels can render earlier.
- On a refetch, Solid normally holds the settled view while new work is in flight. Use `isPending(() => value())` to dim/show “updating”; use `latest(() => value())` where showing freshest in-flight input is right. Use `<Loading on={key()}>` when a changed key should deliberately return to a placeholder.
- Place sibling `<Loading>` boundaries under `<Reveal>` when their visual reveal order matters and independent response timing would cause layout jumps.
- An async dependency tree does not automatically waterfall: create independent memos before rendering and nest boundaries based on the UI dependency graph. Start work high enough to avoid waterfalls but block/render low enough to retain the useful shell.

```tsx
const ProductPane = (props: { productId: string }) => {
  const product = createMemo(() => api.getProduct(props.productId));

  return (
    <Errored fallback={(error, reset) => <LoadFailure error={error()} retry={reset} />}>
      <Loading fallback={<ProductSkeleton />}>
        <ProductDetails product={product()} />
      </Loading>
    </Errored>
  );
};
```

Do not manually maintain `data/loading/error/requestId/AbortController` signal clusters when the async computation or query library owns those states. Treat cancellation and stale-result behavior as part of the request boundary.

## Mutations and optimistic state

Choose the owner of remote state first. A local form draft is not the confirmed server record. Never create a second permanent signal/store copy of query data merely to make writes appear.

### Solid 2 core optimistic-mutation path

Use `action(function* ...)` for a multi-step mutation whose writes cross a promise boundary. Writes to `createOptimistic` or `createOptimisticStore` inside the action are tentative: they appear immediately and are removed automatically when the action settles, including failure. Yield promises—do not use a plain `await` after an optimistic write, because that leaves the transaction.

```ts
const [cart, setCart] = createOptimisticStore(() => getCart(), { items: [] });

const changeQuantity = action(function* (lineId: string, quantity: number) {
  setCart((draft) => {
    const line = draft.items.find((item) => item.id === lineId);
    if (line) line.quantity = quantity;
  });
  yield api.updateCartLine(lineId, quantity);
  yield refresh(cart); // reconcile the confirmed server state
});
```

Use `affects(source, key?)` so a specific row reports pending via `isPending`; use `until()` only when an external confirmation/event must be observed. Catch expected, recoverable validation/conflict errors inside the action; let unexpected rendering/data failures reach `<Errored>`. Never call `flush()` in an action.

### TanStack Solid Query path

When `@tanstack/solid-query` is established, it owns HTTP server state:

- Use `useQuery(() => queryOptions)`/`useQueries` for reads, with stable domain keys containing every input (`["project", projectId]`, not an anonymous object or broad `['api']`). Use `enabled` for a required value that is not available yet.
- Keep query functions typed and return a normalized domain value, not `Response`, an un-narrowed OpenAPI status union, or an ad-hoc transport wrapper.
- Use `useMutation(() => mutationOptions)` for writes. On success, invalidate exactly the affected keys or update the cache with the confirmed response. For optimistic updates, cancel affected reads, snapshot the exact old cache, write the optimistic value in `onMutate`, restore on `onError`, and invalidate on settlement. Handle concurrent mutations deliberately.
- Render `isPending`, `isError`, `error`, empty data, and refetch state; use a nearby `<Loading>`/`<Errored>` only when the query integration actually suspends/throws in the project’s configuration. Do not assume React Query examples map 1:1 to Solid’s reactive accessors—inspect the installed Solid adapter’s types and existing code.

## File-based routing and URL state

First identify the router. Solid’s v2 docs recommend **Solid Router 2** for new file-routed Solid apps; use TanStack Router only where it is already selected or its typed search/loader conventions are needed. Do not mix router generations or mount more than one router instance.

### Solid Router 2

- The CLI convention is routes under `src/routes`, delivered by the Vite file-routes plugin as `virtual:file-routes`. The usual module-level setup converts `pageRoutes` with `fileRoutes()` and creates one `createRouter` instance. Treat generated manifests and route artifacts as read-only.
- Route files supply a default component and may supply route configuration. Follow the repository’s nested or flat filename convention exactly; the v2 filesystem router supports both. Use layouts/pathless route groups for persistent shells and shared guards rather than duplicating navigation and auth checks per page.
- Use router-provided `paths` for compiler-checked URLs, plain anchors/typed router navigation for navigation, and `useLocation`, `useParams`, `useSearchParams`, `useNavigate`, and link state only beneath the router/route owner.
- Validate/narrow params and search at the route boundary. Search params are strings on the wire: parse pagination, filters, sort, and optional state once. URL-owned, shareable state must not be mirrored in signals.
- Use route `preload` and link preloading to start data before the component exists. Route data should share the same query/cache key as the component read, otherwise a preload becomes a duplicate request.
- This is a static SPA backed by a Rust HTTP API. Prefer the project’s established OpenAPI client and TanStack Solid Query for remote reads/writes; do not introduce Solid Router `query()`/`action()` or fullstack data APIs.
- A route guard improves navigation UX only. It may redirect an unauthenticated user before a protected page paints and preserve a validated `next` URL, but the Rust API must authenticate and authorize every request independently.

### TanStack Router

Follow the repository’s generated file-route plugin and route tree; never hand-edit its generated tree. Keep params/search schemas in the route definition, pass typed values into `queryOptions`, and prefetch in loaders without maintaining a second fetching mechanism.

## Typed OpenAPI boundary

`openapi-typescript` is the API schema source of truth. Generated types must be regenerated by the project script/CI, never hand-edited or duplicated. Keep the schema-generated client at the transport boundary and expose small domain operations/query options to UI.

The `openapi-hooks` package’s `createFetch<paths>()` validates literal path, method, parameters, body content type, and produces a discriminated response union by status. It deliberately does **not** throw for non-2xx HTTP responses. Narrow the status before consuming `data`; turn expected statuses into an explicit domain result and unexpected statuses into a thrown error only at the query/mutation boundary.

```ts
// api/client.ts — use the project’s generated `paths` type.
export const apiFetch = createFetch<paths>({ baseUrl: apiBaseUrl });

// api/projects.ts
export const getProject = async (projectId: string) => {
  const response = await apiFetch("/projects/{projectId}", "get", {
    path: { projectId },
  });
  if (response.status === 200) return response.data;
  if (response.status === 404) return null;
  throw new Error(`Could not load project (${response.status})`);
};

export const projectQueryOptions = (projectId: string) =>
  queryOptions({
    queryKey: ["project", projectId],
    queryFn: () => getProject(projectId),
  });
```

- Use only schema-defined paths, lowercase HTTP methods, parameter objects (`path`, `query`, `header`), and declared `contentType`/`data`. Do not manually concatenate endpoint URLs, cast request bodies, or copy generated schemas into UI types.
- Create one configured browser fetch client. Make auth headers a current token function (not a token captured at module initialization). A browser cannot keep a secret: never put privileged API credentials in the bundle. Define a deliberate global policy for network failures and 401/refresh behavior.
- Preserve status distinctions: 400/422 validation, 401 unauthenticated, 403 unauthorized, 404 absent, 409 conflict, and 429 rate-limited have different UI/retry behavior. Validate untrusted route and browser input, and rely on the Rust API to validate and authorize every request.
- `openapi-hooks` documents React Query examples; in Solid applications use its framework-neutral fetcher with **`@tanstack/solid-query`**, not React hooks. Confirm the installed package/version API rather than importing `@tanstack/react-query` into a Solid app.

## Ethereum dapps: viem and wagmi

Use the project’s existing Solid-compatible integration. `wagmi` core/react exports and many online examples are React-hook based; do not call React hooks inside Solid components. If the project uses a Solid adapter/wrapper, follow its established provider and reactive API. Otherwise use viem clients/actions and bridge subscriptions into owned Solid primitives.

- Keep public client, chain definitions, ABIs, and contract addresses typed and centralized by domain. Use viem’s `Address`, `Hex`, ABI inference, `parseUnits`, and `formatUnits`; never use JS `number` for wei, token amounts, chain IDs requiring precision, or balances. Name units (`amountWei`, `gasLimit`, `chainId`).
- Treat the wallet account, connector, selected chain, and transaction lifecycle as external asynchronous state. Explicitly represent disconnected, connecting, wrong-chain, rejected, pending, reverted, and confirmed—not merely “loading.” Request a chain switch before a write when appropriate.
- Reads that must stay fresh belong in a query/cache or an owned subscription; invalidate/refetch relevant reads after a confirmed transaction. A submitted hash is not confirmation. Wait for the required receipt/confirmations, surface a block-explorer link, and decode/display revert errors safely.
- Never trust client wallet state as authorization. Verify signatures, ownership, allowlists, and transaction effects in the Rust API and/or on-chain as appropriate. Do not place private keys, privileged RPC credentials, or signing clients in browser code.
- Abort/clean up account, chain, block, and contract event watchers when their owner is disposed. Avoid duplicate watchers across route mounts.

## Live data: SSE and WebSocket

For simple server-to-browser one-way updates, prefer SSE (`EventSource`); use WebSocket only when bidirectional protocol/low-latency commands warrant its lifecycle complexity. Own a connection in a component/context/custom `createX` primitive, reconnect with bounded backoff, close it in cleanup, and guard messages by the current topic/account/route so stale connections cannot update current UI.

Use the stream as an **invalidation or reconciliation signal**, not an uncontrolled second copy of all server state:

1. Validate/decode every message at the boundary.
2. For low-frequency events, invalidate the narrow query key and refetch.
3. For high-frequency, ordered data, update the precise cache/store immutably with a sequence/version check; resync after reconnect or a gap.
4. Batch/coalesce bursts and bound retained history. Show connection/reconnecting/stale status without blanking useful settled content.

```ts
const createProjectEvents = (projectId: Accessor<string>) => {
  const [status, setStatus] = createSignal<"connecting" | "open" | "closed">("closed");
  const queryClient = useQueryClient();

  createEffect(
    () => projectId(),
    (currentProjectId) => {
      const source = new EventSource(`/api/projects/${encodeURIComponent(currentProjectId)}/events`);
      setStatus("connecting");
      source.onopen = () => setStatus("open");
      source.onmessage = (event) => {
        const message = parseProjectEvent(event.data); // validate unknown input
        if (message.projectId === currentProjectId) {
          void queryClient.invalidateQueries({ queryKey: ["project", currentProjectId] });
        }
      };
      source.onerror = () => setStatus("closed");
      return () => source.close();
    },
  );

  return { status };
};
```

Place live reads behind local `<Loading>` and `<Errored>` boundaries, and ensure reconnects cannot create duplicate streams.

## Static-SPA deployment boundary

This frontend is built as static client assets and served by Rust; it does not use Solid Start, Solid server functions, SSR, hydration, streaming HTML, or server-side route loaders.

- Use Vite client environment values only for public, build-time configuration such as an API base URL. `VITE_*` is public by design—never put a secret, private key, privileged token, or trusted authorization decision there.
- Configure the Rust host to serve hashed static assets and fall back to `index.html` for non-file client routes, so deep links and refreshes reach the SPA.
- The browser owns UI state and calls the Rust API. The Rust API owns secrets, sessions/cookies, authorization, validation, persistence, and API-side rate limiting. Do not disguise a backend concern as a client route guard or TypeScript type.

## Debugging and completion checklist

When something fails to update, ask: (1) was it read as `value()` in JSX/a tracked scope? (2) was a prop destructured or a snapshot captured? (3) did a dependency read happen before the first `await`? (4) did a store update go through its draft setter? (5) is the component/primitive still owned and mounted? Development diagnostics such as `STRICT_READ_UNTRACKED`, `NO_OWNER_EFFECT`, `NO_OWNER_CLEANUP`, and `SILENT_HOLD` identify these mistakes—fix the dataflow rather than suppressing them.

Before completing Solid work:

- Confirm Solid **2** APIs are used (`Loading`/`Errored`, async memos/actions), not copied Solid 1 APIs.
- Confirm every route parameter/search value and external payload is validated/narrowed at its boundary.
- Verify initial loading, stale/refetch, empty, expected-error, unexpected-error/retry, and mutation success/failure states.
- Verify keyboard behavior, focus, labels, semantics, and responsive layout for changed UI.
- Verify cache invalidation/reconciliation after every write and cleanup of timers/listeners/subscriptions.
- For dapps, verify disconnected/wrong-network/rejected/pending/reverted/confirmed flows on the intended chain.
- Run the repository’s type check, lint, tests, and production static build. Check route refresh/deep-link behavior against the Rust static-file host and confirm generated files were not edited.
