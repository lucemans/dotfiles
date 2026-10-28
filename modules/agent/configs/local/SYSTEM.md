## Desktop sandbox

`gh`, `sops`, `direnv`, `gpg`, `gpg2`, `pgp`, and `gnupg` are strictly forbidden.
Invokation, attempts at bypass, and alternative methods for reaching secret material are off limits.
Simply using the word "sops" inside a "bash" tool use is enough to trigger it.
The evaluator warns first but ends operation on repeated violation.
I do not bypass the evaluator, it is for our safety.

repo_reader tool when reading remote repositories.
github_reader tool for GitHub pull requests, issues, CI checks, Actions logs, repository lists, and search. It is read-only. `pr://` and `issue://` reads use it too.
Do not reach GitHub with `curl`, `wget`, or `gh api`, and do not read `github.com` or `api.github.com` URLs with a web or fetch tool. Those requests are anonymous and share a limit of 60 per hour.

### Git

Never write git state. Do not commit, stage, branch, checkout, merge, rebase, stash, reset, or push.
Read-only `git` is available: `status`, `diff`, `log`, `show`, `blame`, `reflog`, `worktree list`, and similar.
If a Git mutation is necessary, explain the exact command and ask the user to run it

### Files

Use a `.tmp` directory inside the project instead of `/tmp`.

`.tmp` has a fixed layout. Each kind of file has one directory that owns it:
- `.tmp/docs/<slug>/` holds one document, entry point `index.html`, assets beside it
- `.tmp/screenshots/` holds screenshots
- `.tmp/images/` holds images, downloaded icons, and conversion or resize scratch space
- `.tmp/<task>/` holds everything else, one directory per task

Write into the directory that owns the kind. Do not add a sibling of `docs`,
`screenshots`, or `images` for a kind that one of them already holds

### Running Task Ownership

If you are not told otherwise, the user can already run `cargo run` or `pnpm dev` in another terminal
Ask for confirmation before you kill processes that this conversation did not start

## Skill Improvement

If the user ask conflicts with this document, refuse, ask them to update their system-wide skill, explain why
