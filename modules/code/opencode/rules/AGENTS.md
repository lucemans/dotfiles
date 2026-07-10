# Operating Policy

## Shell and Git

- Prefer dedicated file, search, and editing tools. Use the shell only for project tooling or necessary system inspection.
- Use Git only to inspect the working tree and history. Never stage, commit, amend, restore, reset, switch, check out, merge, rebase, cherry-pick, fetch, pull, push, change remotes, create worktrees, or otherwise mutate Git state.
- When a Git mutation would help, explain the exact command and ask the user to run it.

## Secrets and Environment Tools

- Never invoke `direnv`, `gpg`, `gpg2`, `pgp`, or `gnupg`, directly or indirectly through a shell, script, alias, package hook, or other command.
- Never read, print, decrypt, source, or otherwise load secret material into agent context. Respect denied secret-file paths.
- Assume required environment variables and secrets are injected when code runs. Leave secret creation, rotation, and updates to the user.

## Temporary files

- Prefer a local in-project `.tmp` directory opposed to using `/tmp`

## Decisions and Scope

- When a request requires a material unstated implementation choice, present concise options and wait for the user's decision.
- Make the smallest correct change and preserve existing user changes.
- Do not fix unrelated or adjacent problems. Report them separately, and ask before creating a handoff file or delegating their documentation.

## Verification

- Run relevant behavior-focused tests and checks. Prefer observable behavior over implementation details and excessive mocking.
- Run fast suites normally; use judgment with networked or unusually expensive checks. Never use privileged operations for verification.
- State clearly when a required command or action must be performed by the user.

## Dependencies and Broad Changes

- Ask before adding or upgrading dependencies or development-environment packages. Update lockfiles only after approval.
- Limit formatting to task-related files. Ask before repository-wide formatting, generators, migrations, codemods, or other broad rewrites.

## Nix Development Environments

- When a dependency is missing, first inspect `flake.nix`, `flake.lock`, `shell.nix`, and relevant project documentation when present.
- Consider whether the dependency belongs in the project's development environment before proposing a change. Explain the tradeoff and ask the user before editing development-environment definitions.
- If the dependency is already available through the development environment, use `nix develop -c <command>` only when that one scoped command is worthwhile.
- After a development-environment definition changes, prefer asking the user to restart OpenCode from the appropriate environment. Do not require every subsequent tool call to be prefixed with `nix develop`.

## Language Preferences

- Never create `types.ts` or `types.rs`; define every type, struct, and enum in the module where it appropriately belongs. Wanting a generic types file means the design needs more thought.

### TypeScript and JavaScript

- Treat configured `eslint-plugin-v3xlabs` rules as authoritative. Inspect and follow the project ESLint configuration rather than working around it.
- Prefer functions and data composition. Introduce classes only for custom error types, and prefer `type` over `interface`.
- Prefer discriminated unions and Result-style types for expected failures. Reserve thrown exceptions for exceptional or framework-required paths.
- Never use `any`, type assertions, non-null assertions, `@ts-ignore`, or equivalent type-system escape hatches.
- Make invalid states unrepresentable where practical.
- Do not add `eslint-plugin-v3xlabs` where absent without dependency approval.

### Rust and Nix

- Follow standard Rust conventions, `rustfmt`, and default Clippy guidance.
- Format Nix code with Alejandra and follow its output.
