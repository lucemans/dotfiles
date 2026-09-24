---
name: maintain
description: Workflow for maintaining a project, updating & auditing dependencies, and more.
disable-model-invocation: true
---

A quick rundown on maintaing a repository.

## Audit Dependencies

Perform the ecosystem specific expected auditing step, `cargo audit` `pnpm audit` etc.
Observe open dependabot pull requests.

## Update first, question later

Update to the recommended stable versions, not the bleeding latest unless security critical or explicitly asked.
Observe changelogs, and attempt up to minor version bumps, dont start with cautious shape comparisons, try it, see what breaks.

## Report Results

Produce an overview of updated packages, before & after column's, extra notes if needed.
A "stable" and "latest" column show the gap between results and recommended.
Mention potential new security vectors, aswell as vectors patched with these upgrades.
Evaluate wether any of the patched by these updates are of high severity, and provide this as indication of return on maintenance cost.
