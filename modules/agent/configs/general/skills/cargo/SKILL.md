---
name: cargo
description: Rust and Cargo conventions. Use when reading, reviewing, or changing Rust files, Cargo.toml, or Cargo workspace
---

# Cargo

## Definition of Done

`cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test` all pass

## Expectations

Toolchain comes from Nix, not `rust-toolchain.toml`
Lint config lives in repository: `[lints.clippy]` table, `clippy.toml`, and `.rustfmt.toml`
Never add `#[allow]`
Fix code, or raise lint with user
Approved override: `#[expect(lint, reason = "...")]` on the smallest item that triggers it (M-LINT-OVERRIDE-EXPECT)

## Rules

Follow while writing code
IDs like `M-PANIC-ON-BUG` are [Microsoft's Pragmatic Rust Guidelines](https://microsoft.github.io/rust-guidelines/guidelines/checklist/), [summarized documentation](https://microsoft.github.io/rust-guidelines/agents/all.txt)

**Conversions**
Use `impl From`/`impl TryFrom`/`impl FromStr`, not a loose fn taking one value and returning another type
Invariant-holding newtype has private field; converts from raw type only via `TryFrom`/`FromStr`, never `From`
M-STRONG-TYPES-GUARD

**Functions**
Fn whose first param is this crate's `T`/`&T` is a method on `T`
Fn building/returning `T` are `T::new`, named constructor, or `From` impl
Associated fn without `self` is a constructor
Helper neither taking nor building `T` is loose fn in `T`'s module: `user::normalize_name`, not `User::normalize_name`
When body is call on one value, that value's type owns the Fn
Loose Fns only for ownerless work (wiring `main.rs`, route registration), sole exception are fereign types
M-REGULAR-FN

**Types, Enum, Trait, Dyn, Pointers**
- Concrete type
- Enum when every impl is known
- Narrow trait as generic when caller is BYO impl
- `dyn Trait` last; inside newtype
No single-impl trait
No `Arc`, `Rc`, `Box`, `RefCell`, `Mutex` in public signatures
In tests, double enum variant deviates: no mocks
M-DI-HIERARCHY M-AVOID-WRAPPERS

**Paths**
Filesystem paths are `Path`/`PathBuf`, never `String`; join with `Path::join`, not `format!`

**Parse separately from reading**
Parsers take `&str`, `&[u8]`, or `impl Read`, thin Fns opens file and calls it
Tests pass with literals, not tempfiles
M-STRONG-TYPES M-IMPL-IO

**Chosen Constants**
Chosen values (think timeout, limit, pool size, retry count) are named `const`
Its doc says why it exists, what breaks if changed, and outside-system dependencies.
Values following from meaning (`0`, `1`, `len() -1`) stay inline.
M-DOCUMENTED-MAGIC

**Naming Types**
Types name their use: `Users`, `Sessions`, `Dispatcher`
No `AbstractSingletonProxyFactoryBean`
Words only stating the type add nothing
`Factory` is a builder or parameter of type `impl Fn() -> T`
No repeating module names: `session::Store` not `session::SessionStore`
OpenAPI schema types require crate-wide unique names
Id types name the entity, `UserId` never `Id`
Error types keep prefixes like `ConfigError`
M-WEASEL-WORDS M-SHORT-NAMES

**Visibility**
`pub` or nothing
`pub(crate)` banned and sloppy
Items consumers must not see go in a private module
Every public item has one path
No `pub use x::*` and no re-export of another crate's type
A library may define one `prelude` module
M-SINGLE-ITEM-PATH M-NO-GLOB-REEXPORTS M-FOREIGN-REEXPORTS. The prelude deviates from M-NO-PRELUDE.

**Files**
One concept per file
No `models.rs`
Growing impl blocks move into their own file
Never both `thing.rs` and `thing/` or `thing/thing.rs`
Split by concept before 500 lines
Past 1000 lines unacceptable
Bulky tests move to `#[cfg(test)] mod tests;`

**Errors**
Expected failures are `thiserror` enums
Fn error types listing only failues that fn can produce
One crate-wide `Error` fine while fns share failures
When crate grows, split by operation family (`ConfigError`, `FetchError`), each in its own module
Convert with `#[from]` and `?`
`map_err` only adds context upstream lacks (eg failing path), keeping cause in `#[source]` field
Never drop cause with `map_err(|_| ...)`
M-FROM-ERROR M-ERRORS-CANONICAL-STRUCTS (deviation: no backtrace struct, no hidden `ErrorKind`)

**Bugs**
Broken invariant is a bug, not expected failure
Panic via `.expect("why this cannot fail")`
No error variant no caller can act on
`unwrap` belongs in tests
Every non-test `assert!` `unreachable!` `todo!` `panic!` has message with involved vlaues
`clippy::missing_assert_message` can enforce it, enable only if quiet on test code
M-PANIC-ON-BUG M-PANIC-MESSAGE

**Enums**
Variant named string literal enums use `strum`
Derive `Display` and `EnumString` with `serialize_all` instead, no handwritten mappings

**Logs & Tracing**
`tracing` with named fields and fixed message: `info!(user.id = %id, "user logged in")`
Never format values into message
Use OpenTelemetry field names where one exists (`url.path`, `db.operation.name`)
`println!`/`dbg!` only for output a CLI prints for its user
M-LOG-STRUCTURED M-LOG-NOT-PRINT (`{{field}}` message templates deviate: message stays plain text)

**Secrets, Passwords, Tokens, Keys**
Live in wrapper type with hand-written `Debug` printing no value, no `Serialize`
Raw value only via named method like `expose()`
M-PUBLIC-DEBUG

## Lints for a new repository

[Cargo.toml](./Cargo.toml) [clippy.toml](./clippy.toml)

`arbitrary_source_item_ordering` checks module-level order against clippy's default groups, where `fn` is last.
A free function above a type declared later in the file fails.
The `source-item-ordering` setting keeps the check at module level, so enum variants and struct fields keep the order you wrote.

Keep `redundant_pub_crate` at warn.
Do not enable rustc's `unreachable_pub`.
It flags every `pub` item in a private module and tells you to downgrade to `pub(crate)`, the pattern the visibility rule bans.
No lint bans `pub(crate)` outright.
Review enforces it.

## Workspaces

Lint tables live in the root as `[workspace.lints.rust]` and `[workspace.lints.clippy]`.
Every member has `[lints] workspace = true`, or no lints run on it.
A member with that line cannot add lint entries of its own.

Every dependency, including a sibling crate, is declared once in `[workspace.dependencies]` with `default-features = false`.
A member enables only the features it uses: `tokio = { workspace = true, features = ["rt"] }`.
A sibling entry has a `path`, and a `version` only when the crate is published.
Members live flat under `crates/`.
New crates use edition 2024.
A virtual workspace sets `resolver = "3"`, because without a root package Cargo falls back to resolver 1.
An existing workspace keeps its layout.
See M-CARGO-WORKSPACE, M-CRATES-IN-WORKSPACE, M-CRATES-FLAT-FOLDER, M-LATEST-EDITION. The `resolver` line and the optional `version` deviate.

## Formatting

```toml
# .rustfmt.toml
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

Both options are nightly only.
Stable rustfmt ignores them and exits zero, so formatting passes locally and fails in CI.
Use them only if nightly rustfmt is already in the devshell.
Do not move a repository to nightly for them.
Do not change a `.rustfmt.toml` the repository already has.

## sqlx

`sqlx::migrate!` is a proc macro on the `macros` feature, which is separate from `migrate`.
Without it the build fails with `cannot find 'migrate' in 'sqlx'`.

The compile-time `query!` and `query_as!` macros check against a live database or a committed `.sqlx` cache.
A new migration breaks the build until one of the two catches up.
Runtime `query_as::<_, T>()` with a `FromRow` derive has no such failure mode.

SQLite has no unsigned integer type.
Give an id newtype one `Type`, `Decode`, and `Encode` impl instead of casting at every row mapping site.

## poem and poem-openapi

`#[derive(Object)]` serializes a `None` field as `null`.
Add `#[oai(skip_serializing_if_is_none)]` to any output struct that has an `Option` field.

A field typed by another crate, such as `chrono` or `uuid`, needs that crate's feature on `poem-openapi` itself.

`poem::test::TestClient` is behind poem's `test` feature.
Add it as a dev dependency when the crate is scaffolded.

A handler returns a `#[derive(ApiResponse)]` enum whose variants carry `#[oai(status = ...)]`.
The domain type reaches the response type through `impl From`, not through a conversion function.
