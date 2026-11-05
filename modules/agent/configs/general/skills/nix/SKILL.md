---
name: nix
description: Useful nixos, development environment, flake, and devshell information
---

### Nix Development Environments

If a dependency is missing, first look at `flake.nix`, `flake.lock`, `shell.nix`, and related project documentation
Before you propose a change, think about whether the dependency belongs in the project development environment
Explain the tradeoff and ask the user before you edit development-environment definitions
If the dependency is already available in the development environment, use `nix develop -c <command>` only when that one command is worth it
After a development-environment definition changes, ask the user to restart the harness from the correct environment
Do not require every subsequent tool call to start with `nix develop`
