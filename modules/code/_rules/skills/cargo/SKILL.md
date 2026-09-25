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
Never add an `#[allow]` to silence a lint.
Fix the code, or raise the lint with the user to change a table.

## Beyond the lints

Follow these while you write the code.

Conversion between two types is `impl From`, `impl TryFrom`, or `impl FromStr`.
A free function that takes one value and returns a different type is the wrong shape.

A function whose first parameter is a `T` or `&T` from this crate is a method on `T`.
A function that builds and returns a `T` is `T::new`, a named constructor, or the `From` impl above.
If the body is calls on one value, that value's type owns the function.
Free functions are for work with no owning type, such as wiring in `main.rs` or route registration.
The orphan rule is the one exception.
A foreign type cannot gain an impl here.

Visibility is `pub` or nothing.
`pub(crate)` is banned.
It keeps an item out of the public API while leaving it reachable from every module, so no module owns its contract.
An item consumers must not see goes in a private module.
`pub` inside a private module still reaches the whole crate and exports nothing.
An item one sibling module needs is `pub(super)`.
This holds in binary crates, where `pub` exports nothing anyway.

One concept per file.
No `models.rs`.
A growing impl block moves to its own file.
A concept never has both `thing.rs` and `thing/`.

Split a file by concept before it reaches 500 lines.
A file past 1000 lines is unacceptable.
If tests are the bulk of a long file, move them to their own file behind `#[cfg(test)] mod tests;`.

Expected failures are a `thiserror` enum.
`unwrap` and `expect` belong in tests.

An enum whose string form is its variant name in another case uses `strum`.
Derive `Display` and `EnumString` with `serialize_all` instead of writing the mapping by hand.

## Lints for a new repository

```toml
# Cargo.toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"
todo = "warn"
missing_errors_doc = "allow"
redundant_pub_crate = "warn"
arbitrary_source_item_ordering = "deny"
```

```toml
# clippy.toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
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
