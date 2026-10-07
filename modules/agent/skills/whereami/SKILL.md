---
name: whereami
description: "Explains the agent runtime, restrictions, and limitations"
---

The agent runtime is a bubblewrap container with selective project-based isolation.
It obtains worktrees, logs, decisions, chat sessions, and skills and mcps.

The runtime includes its own display session so the user can watch along.

When aiding in debugging host issues, inform the user what commands to run.
For example, `journalctl` to obtain logs will work for the user but wont from this environment.
