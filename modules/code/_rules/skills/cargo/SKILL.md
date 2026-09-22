---
name: cargo
description: Rust and Cargo conventions. Use when reading, reviewing, or changing Rust files, Cargo.toml, or a Cargo workspace.
---

# Cargo

`cargo fmt` and `cargo clippy --all-targets -- -D warnings` settle every formatting and lint
question. Run both, and `cargo test`, before you report Rust work as done. If the repository has
a devshell, run them through it: `nix develop -c cargo test`. The toolchain comes from Nix, not
from a `rust-toolchain.toml`.

Lint configuration lives in the repository, in a `[lints.clippy]` table, in `clippy.toml`, and in
`.rustfmt.toml`. Do not add an `#[allow]` to silence a lint. Fix the code, or raise the lint with
the user and change the table.

## Four things the lints do not check

- Conversion between two types is `impl From`, `impl TryFrom`, or `impl FromStr`. A free function
  that takes one value and returns a different type is the wrong shape.
- Default visibility is `pub`. `pub(crate)` needs a reason you can state.
- One concept per file. No `models.rs`. A growing impl block moves to its own file, and a concept
  never has both `thing.rs` and `thing/`.
- Expected failures are a `thiserror` enum. `unwrap` and `expect` belong in tests.

## Lints for a new Rust repository

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

`arbitrary_source_item_ordering` checks module level order against clippy's default groupings, in
which `fn` is the last group. A free function above a type declared later in the file fails. The
`source-item-ordering` value keeps the check at module level, so enum variants and struct fields
stay in the order they were written. `redundant_pub_crate` is a nursery lint and contradicts
rustc's `unreachable_pub`. Enable one of the two, at warn level.

A repository that already has a different table keeps it. Do not rewrite an existing table to
match this one.

## Formatting

```toml
# .rustfmt.toml
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

Both options are nightly only. Stable rustfmt ignores them and exits zero, so formatting passes
locally and fails in CI. Use them if nightly rustfmt is already in the devshell. Do not move a
repository to nightly for them, and do not change a `.rustfmt.toml` the repository already has.

## sqlx

- `sqlx::migrate!` is a proc macro and needs the `macros` feature, which is separate from
  `migrate`. Without it the build fails with `cannot find 'migrate' in 'sqlx'`.
- The compile time `query!` and `query_as!` macros check against a live database or a committed
  `.sqlx` cache, so a new migration breaks the build until one of the two catches up. Runtime
  `query_as::<_, T>()` with a `FromRow` derive has no such failure mode.
- SQLite has no unsigned integer type. Give an id newtype one `Type`, `Decode`, and `Encode` impl
  instead of casting at every row mapping site.

## poem and poem-openapi

- `#[derive(Object)]` serializes a `None` field as `null`. Add `#[oai(skip_serializing_if_is_none)]`
  to any output struct that has an `Option` field.
- A field typed by another crate, such as `chrono` or `uuid`, needs that feature on `poem-openapi`
  itself.
- `poem::test::TestClient` is behind poem's `test` feature. Add it as a dev dependency when the
  crate is scaffolded.
- A handler returns a `#[derive(ApiResponse)]` enum whose variants carry `#[oai(status = ...)]`.
  The domain type reaches the response type through `impl From`, not through a conversion function.
