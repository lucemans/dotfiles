---
name: maintain
description: Workflow for maintaining a project, updating & auditing dependencies, and more.
disable-model-invocation: true
---

A rundown on maintaining a repository.
Invoking this skill is the approval: update dependencies and lockfiles without asking first.

## Audit Dependencies

Run the ecosystem's expected audit step.
Get missing tools from nixpkgs, never a global install:
`nix shell nixpkgs#cargo-audit -c cargo audit`, `pnpm audit` etc.
Observe open dependabot pull requests.

## Update first, question later

Update to stable, not latest, unless security-critical or explicitly asked.
- stable: newest version semver-compatible with the declared range (`cargo update`, `pnpm update`)
- latest: newest published, including majors (`nix shell nixpkgs#cargo-outdated -c cargo outdated`, `pnpm outdated`)

Bump, build, see what breaks, read the changelog when something does.

## Report Results

Table with before, stable, and latest columns.
Note vulnerabilities patched and new exposure introduced.
Flag any patched advisory of high severity and provide a 'value of this update' estimate.
