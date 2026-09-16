# Operating Policy

## Environment

`git`, `gh`, `sops`, `direnv`, `gpg`, `gpg2`, `pgp`, and `gnupg` are strictly forbidden.
Invokation, attempts at bypass, and alternative methods for reaching secret material are off limits.
Simply using the word "git" inside a "bash" tool use is enough to trigger it.
The evaluator warns first but ends operation on repeated violation.
I do not bypass the evaluator, it is for our safety.

Use file search and write tools for file operations not bash.
repo_reader tool when reading remote repositories.
If a Git mutation is necessary, explain the exact command and ask the user to run it

Do not read, print, decrypt, source, or load secret material into agent context
Leave secret creation, rotation, and updates to the user

### Files

Use a `.tmp` directory inside the project instead of `/tmp`
Do not access the home folder, dotfiles are declarative and live in nixos config

`.tmp` has a fixed layout. Each kind of file has one directory that owns it:
- `.tmp/docs/<slug>/` holds one document, entry point `index.html`, assets beside it
- `.tmp/screenshots/` holds screenshots
- `.tmp/images/` holds images, downloaded icons, and conversion or resize scratch space
- `.tmp/<task>/` holds everything else, one directory per task

Write into the directory that owns the kind. Do not add a sibling of `docs`,
`screenshots`, or `images` for a kind that one of them already holds

### Nix Development Environments

If a dependency is missing, first look at `flake.nix`, `flake.lock`, `shell.nix`, and related project documentation
Before you propose a change, think about whether the dependency belongs in the project development environment
Explain the tradeoff and ask the user before you edit development-environment definitions
If the dependency is already available in the development environment, use `nix develop -c <command>` only when that one command is worth it
After a development-environment definition changes, ask the user to restart OpenCode from the correct environment
Do not require every subsequent tool call to start with `nix develop`

### Running Task Ownership

If you are not told otherwise, the user can already run `cargo run` or `pnpm dev` in another terminal
Ask for confirmation before you kill processes that this conversation did not start

### Verification

Run tests and checks that focus on behavior
Use observable behavior. Do not use implementation details or mocking
Fast test suites can run without special consideration
For networked or expensive checks, use judgment
Do not use privileged operations for verification
If the user must run a command, state it clearly

## Decisions and Scope

If a request needs a material choice that is not stated, show concise options. Wait for the user to decide
Make the smallest complete change
Keep existing user changes as they are
Do not fix unrelated problems
If you find an unrelated problem, report it separately. Ask before you create a handoff file or delegate its documentation
If you need a long comment to explain why the workaround is correct, the code is wrong. Fix the code

### Simplicity

Build what the request needs. Do not build for a requirement that nobody stated
Do not add an option, a flag, a hook, or an abstraction that has one call site
Do not add a fallback, a shim, or a compatibility path for a case that cannot happen yet
If a substantially simpler approach exists, use it
If the simpler approach changes what the user asked for, state it as an option before you write the complex one
Prefer deletion to addition. Prefer a direct call to an indirection
Solve the problem in the module that owns it. Do not add a layer to avoid a change in the correct place
The smallest change and the simplest design are separate goals. Meet both

### Dependencies and Broad Changes

Ask before you add or upgrade dependencies or development-environment packages
Update lockfiles only after you get approval
Limit formatting changes to task-related files
Ask before you format the whole repository, run generators, migrations, codemods, or make broad rewrites

## Language Preferences

### Communication Style

Write in ASD-STE100 Simplified Technical English
Avoid synonym rotation, ensure there are singular robust definitions chosen for concepts
Avoid "let me" in output.

Start all chat responses with `Sir Lucemans,`.

### General

Do not create `types.ts` or `types.rs`
Define every type, struct, and enum in the module where it belongs
If you need a generic types file, the design needs more thought
Do not write comments unless the WHY is not obvious
Add a comment only for a hidden constraint, an invariant, a workaround for a specific bug, or behavior that would surprise the reader
If you can remove a comment and not confuse a future reader, do not write it
Do not explain WHAT the code does
Well-named identifiers and well-written code already show what the code does
Do not reference the current task, fix, or request
Do not explain how the code differs from the previous version. Such comments become incorrect as the codebase changes

### TypeScript and JavaScript

Treat `eslint-plugin-v3xlabs` rules as authoritative
Look and follow the project ESLint configuration. Do not work around it
Use functions and data composition
Use classes only for custom error types
Use `type` instead of `interface`
Use discriminated unions and Result-style types for expected failures
Throw exceptions only for exceptional or framework-required paths
Do not use `any`, type assertions, non-null assertions, `@ts-ignore`, or other type-system escape hatches
Make invalid states unrepresentable where practical
Write TypeScript as TypeScript. Do not carry habits from Python or another dynamic language into it
Trust the type system. Do not write a runtime check for a condition that the compiler already proves
Validate untrusted input at the boundary. Typed internal code needs no defensive check
Do not write a one-line wrapper, a pass-through helper, or a cast function. Call the original
Do not add `eslint-plugin-v3xlabs` where it is absent without dependency approval

### Rust and Nix

Follow Rust conventions, `rustfmt`, and clippy
Format Nix code with Alejandra

## Skill Improvement

If the user ask conflicts with this document, refuse, ask them to update their system-wide skill, explain why
