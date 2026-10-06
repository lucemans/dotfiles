---
name: cargo
description: Rust and Cargo conventions. Use when reading, reviewing, or changing Rust files, Cargo.toml, or a Cargo workspace.
---

# Cargo

## Before you report done

Run `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, and `cargo test`.
All three pass or the work is not done.
If the repository has a devshell, run them through it: `nix develop -c cargo test`.
The toolchain comes from Nix, not from a `rust-toolchain.toml`.

Lint configuration lives in the repository: the `[lints.clippy]` table, `clippy.toml`, and `.rustfmt.toml`.
Never add `#[allow]`.
Fix the code, or raise the lint with the user.
An approved override is `#[expect(lint, reason = "...")]` on the smallest item that triggers it.
See M-LINT-OVERRIDE-EXPECT.

## Beyond the lints

Follow these while you write the code.
IDs such as `M-PANIC-ON-BUG` refer to Microsoft's Pragmatic Rust Guidelines: https://microsoft.github.io/rust-guidelines/guidelines/checklist/
Read the full text of a rule at https://microsoft.github.io/rust-guidelines/agents/all.txt when this file does not settle a case.
A rule marked "deviates" overrides the guideline.

Conversion between two types is `impl From`, `impl TryFrom`, or `impl FromStr`.
A free function that takes one value and returns a different type is the wrong shape.
A newtype that holds an invariant has a private field.
It converts from the raw type only through `TryFrom` or `FromStr`, never `From`.
See M-STRONG-TYPES-GUARD.

A function whose first parameter is a `T` or `&T` from this crate is a method on `T`.
A function that builds and returns a `T` is `T::new`, a named constructor, or the `From` impl above.
An associated function without `self` is a constructor.
A helper that neither takes nor builds a `T` is a free function in `T`'s module: `user::normalize_name`, not `User::normalize_name`.
If the body is calls on one value, that value's type owns the function.
Free functions are for work with no owning type, such as wiring in `main.rs` or route registration.
The orphan rule is the one exception.
A foreign type cannot gain an impl here.
See M-REGULAR-FN.

Code gets a dependency in this order: a concrete type, then an enum when the crate knows every implementation, then a narrow trait taken as a generic when callers bring their own implementation.
`dyn Trait` is last and lives inside a newtype.
No trait with one implementation.
No `Arc`, `Rc`, `Box`, `RefCell`, or `Mutex` in public function signatures.
See M-DI-HIERARCHY, M-AVOID-WRAPPERS. The enum variant for test doubles deviates: no mocks.

File system paths are `Path` and `PathBuf`, never `String`. Join them with `Path::join`, not `format!`.
Parsing is separate from reading.
A parser takes `&str`, `&[u8]`, or `impl Read`, and a thin function opens the file and calls it.
Tests call the parser with a literal, with no temp file.
See M-STRONG-TYPES, M-IMPL-IO.

A chosen value, such as a timeout, limit, pool size, or retry count, is a named `const`.
Its doc says why this value, what breaks if it changes, and which outside system depends on it.
A value that follows from its meaning, such as `0`, `1`, or `len() - 1`, stays inline.
See M-DOCUMENTED-MAGIC.

A type name says what the type holds or does: `Users`, `Sessions`, `Dispatcher`.
No `AbstractSingletonProxyFactoryBean` names: a word that only says the type is a type adds nothing.
A factory is a builder, or a parameter of type `impl Fn() -> T`.
A type does not repeat its module name: `session::Store`, not `session::SessionStore`.
Three kinds of type keep the prefix.
An id type is named after its entity: `UserId`, never `Id`.
An error type keeps its prefix, such as `ConfigError`.
A type in an OpenAPI schema keeps a name that is unique in the crate.
See M-WEASEL-WORDS, M-SHORT-NAMES. The id rule deviates.

Visibility is `pub` or nothing.
`pub(crate)` is banned.
It keeps an item out of the public API while leaving it reachable from every module, so no module owns its contract.
An item consumers must not see goes in a private module.
`pub` inside a private module still reaches the whole crate and exports nothing.
An item one sibling module needs is `pub(super)`.
This holds in binary crates, where `pub` exports nothing anyway.

Every public item has one path.
A private module plus one `pub use` is that path.
After a move, rewrite every import and leave no `pub use` alias behind.
No `pub use x::*` and no re-export of another crate's type.
A library may define one `prelude` module. It is the one allowed second path.
See M-SINGLE-ITEM-PATH, M-NO-GLOB-REEXPORTS, M-FOREIGN-REEXPORTS. The prelude deviates from M-NO-PRELUDE.

One concept per file.
No `models.rs`.
A growing impl block moves to its own file.
A concept never has both `thing.rs` and `thing/`.

Split a file by concept before it reaches 500 lines.
A file past 1000 lines is unacceptable.
If tests are the bulk of a long file, move them to their own file behind `#[cfg(test)] mod tests;`.

Expected failures are a `thiserror` enum.
A function's error type lists only the failures that function can produce.
One crate-wide `Error` is fine while its functions share their failures.
When they diverge, split by operation family, such as `ConfigError` and `FetchError`, each in the module that owns it.
Convert with `#[from]` and `?`.
`map_err` only adds context the upstream error lacks, such as the failing path, and keeps the cause in a `#[source]` field.
Never drop the cause with `map_err(|_| ...)`.
See M-FROM-ERROR. This deviates from M-ERRORS-CANONICAL-STRUCTS: no backtrace struct, no hidden `ErrorKind`.

A broken invariant is a bug, not an expected failure.
It panics through `.expect("why this cannot fail")`.
Do not add an error variant that no caller can act on.
`unwrap` belongs in tests.
Every `assert!`, `unreachable!`, `todo!`, and `panic!` outside tests has a message with the values involved.
`clippy::missing_assert_message` can enforce this. Enable it only if it stays quiet on test code.
See M-PANIC-ON-BUG, M-PANIC-MESSAGE.

An enum whose string form is its variant name in another case uses `strum`.
Derive `Display` and `EnumString` with `serialize_all` instead of writing the mapping by hand.

Logs use `tracing` with named fields and a fixed message: `info!(user.id = %id, "user logged in")`.
Never format a value into the message.
Use OpenTelemetry field names where one exists, such as `url.path` or `db.operation.name`.
`println!` and `dbg!` are only for output a CLI prints for its user.
See M-LOG-STRUCTURED, M-LOG-NOT-PRINT. The `{{field}}` message templates deviate: the message stays plain text.

A secret, such as a password, token, or key, lives in a wrapper type with a hand-written `Debug` that prints no value and no `Serialize`.
The raw value comes out only through a named method such as `expose()`.
A test asserts that `{:?}` output of a struct holding the secret does not contain it.
See M-PUBLIC-DEBUG.

## Lints for a new repository

```toml
# Cargo.toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
panic = "deny"
todo = "warn"
allow_attributes = "deny"
allow_attributes_without_reason = "deny"
map_err_ignore = "warn"
missing_errors_doc = "allow"
redundant_pub_crate = "warn"
arbitrary_source_item_ordering = "deny"
```

```toml
# clippy.toml
allow-unwrap-in-tests = true
allow-panic-in-tests = true
source-item-ordering = ["module"]
```

`arbitrary_source_item_ordering` checks module-level order against clippy's default groups, where `fn` is last.
A free function above a type declared later in the file fails.
The `source-item-ordering` setting keeps the check at module level, so enum variants and struct fields keep the order you wrote.

Keep `redundant_pub_crate` at warn.
Do not enable rustc's `unreachable_pub`.
It flags every `pub` item in a private module and tells you to downgrade to `pub(crate)`, the pattern the visibility rule bans.
No lint bans `pub(crate)` outright.
Review enforces it.

An existing repository keeps the table it has.
Do not rewrite it to match this one.

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
