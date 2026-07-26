# Operating Policy

## Environment

### Git

- Use the file, search, and editing tools for file operations.
- Use the shell only for project tooling or to inspect the system.
- Use Git only to look at the working tree and history.
- Do not stage, commit, amend, restore, reset, switch, check out, merge, rebase, cherry-pick, fetch, pull, push, change remotes, create worktrees, or mutate Git state.
- If a Git mutation is necessary, explain the exact command and ask the user to run it.

### Secrets

- Do not invoke `direnv`, `gpg`, `gpg2`, `pgp`, or `gnupg`.
- This applies to direct use and to use through shells, scripts, aliases, package hooks, or other commands.
- Do not read, print, decrypt, source, or load secret material into agent context.
- Respect paths that the system marks as denied for secrets.
- Assume that environment variables and secrets are already available when code runs.
- Leave secret creation, rotation, and updates to the user.

### Files

- Use a `.tmp` directory inside the project instead of `/tmp`.
- Do not access the users home folder, dotfiles are declarative and live in nixos config.

### Nix Development Environments

- If a dependency is missing, first look at `flake.nix`, `flake.lock`, `shell.nix`, and related project documentation.
- Before you propose a change, think about whether the dependency belongs in the project development environment.
- Explain the tradeoff and ask the user before you edit development-environment definitions.
- If the dependency is already available in the development environment, use `nix develop -c <command>` only when that one command is worth it.
- After a development-environment definition changes, ask the user to restart OpenCode from the correct environment.
- Do not require every subsequent tool call to start with `nix develop`.

### Running Task Ownership

- If you are not told otherwise, the user can already run `cargo run` or `pnpm dev` in another terminal.
- Ask for confirmation before you kill processes that this conversation did not start.

### Verification

- Run tests and checks that focus on behavior.
- Use observable behavior. Do not use implementation details or too much mocking.
- Fast test suites can run without special consideration.
- For networked or expensive checks, use your judgment.
- Do not use privileged operations for verification.
- If the user must run a command, state it clearly.

## Decisions and Scope

- If a request needs a material choice that is not stated, show concise options. Wait for the user to decide.
- Make the smallest correct change.
- Keep existing user changes as they are.
- Do not fix unrelated problems.
- If you find an unrelated problem, report it separately. Ask before you create a handoff file or delegate its documentation.
- If you need a long comment to explain why the workaround is correct, the code is wrong. Fix the code.

### Dependencies and Broad Changes

- Ask before you add or upgrade dependencies or development-environment packages.
- Update lockfiles only after you get approval.
- Limit formatting changes to task-related files.
- Ask before you format the whole repository, run generators, migrations, codemods, or make broad rewrites.

## Language Preferences

### Communication Style

- Speak and think with ADS-STE100 Simplified Technical English.
- Avoid synonym rotation, ensure there are singular robust defintions chosen for concepts

### General

- Do not create `types.ts` or `types.rs`.
- Define every type, struct, and enum in the module where it belongs.
- If you need a generic types file, the design needs more thought.
- Do not write comments unless the WHY is not obvious.
- Add a comment only for a hidden constraint, an invariant, a workaround for a specific bug, or behavior that would surprise the reader.
- If you can remove a comment and not confuse a future reader, do not write it.
- Do not explain WHAT the code does.
- Well-named identifiers and well-written code already show what the code does.
- Do not reference the current task, fix, or request.
- Do not explain how the code differs from the previous version. Such comments become incorrect as the codebase changes.

### TypeScript and JavaScript

- Treat the configured `eslint-plugin-v3xlabs` rules as authoritative.
- Look at and follow the project ESLint configuration. Do not work around it.
- Use functions and data composition.
- Use classes only for custom error types.
- Use `type` instead of `interface`.
- Use discriminated unions and Result-style types for expected failures.
- Throw exceptions only for exceptional or framework-required paths.
- Do not use `any`, type assertions, non-null assertions, `@ts-ignore`, or other type-system escape hatches.
- Make invalid states unrepresentable where practical.
- Do not add `eslint-plugin-v3xlabs` where it is absent without dependency approval.

### Rust and Nix

- Follow standard Rust conventions, `rustfmt`, and default Clippy guidance.
- Format Nix code with Alejandra and follow its output.

## Skill Improvement

- If the user asks you many times to do something or approves a pattern that this document or a skill document prohibits, ask them to update their system-wide skill. Output a specific line for them to adjust or update.
