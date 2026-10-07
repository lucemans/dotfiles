---
name: decision-log
description: "Record and read the project's decision log at $AGENT_TRAIL_DIR/decisions.tsv. Read its last rows when work starts or resumes. Append a row when you or the user make a decision that changes the shape of the project, when the user corrects you, or when a run reverts or abandons an approach. Use for 'log this', 'why did we', 'what did we decide', session pickup, and long or unattended work."
---

# Decision log

Each repository has one decision log at `$AGENT_TRAIL_DIR/decisions.tsv`. The sandbox mounts that directory from the host. It is outside the repository, so nothing in it is committed. Every worktree of one repository shares the same log.

## When work starts

Read the last 20 rows before you plan. A row from an earlier run is authoritative input. Do not decide again what a row already decided, unless new evidence contradicts it. In that case, append a row that supersedes it.

## The format

One header row, then one row per decision. The columns are separated by tabs:

```
ts	phase	decision	why	by	evidence	session	result
```

- `ts`. UTC time, `date -u +%Y-%m-%dT%H:%M:%SZ`. This value also identifies the row.
- `phase`. The area or the workstream, for example `auth` or `sandbox`. The value `start` is reserved, see below.
- `decision`. What was chosen, in one line.
- `why`. The reason, in plain words.
- `by`. `user`, `agent:<model>`, or `agent+user` for an agent proposal that the user accepted.
- `evidence`. A pointer, never prose: `file:line`, a commit SHA, a PR, a plan.env.md URL, or a path under `.tmp/`.
- `session`. The harness and the session id, for example `omp:<id>`. If the harness does not show an id, write the harness name and the `ts` of this run's `start` row.
- `result`. The state: `accepted`, `verified`, `reverted`, `open`, or `superseded`.

Example:

```
2026-10-07T14:02:00Z	auth	JWT, not session cookies	the API serves the web app and the CLI, and no request should need a session lookup	user	"jwt, not session cookies"	omp:a1b2	accepted
2026-10-07T14:40:00Z	auth	15 minute access token with a rotating refresh token	a short lifetime limits how long a revoked token stays valid	agent:opus-5.5	src/auth/token.ts:12	omp:a1b2	verified
```

## What to log

- A choice between two or more approaches, with the reason that decided it.
- Every decision from the user: an answer to a question, a correction, or "do Y instead". Set `by` to `user` and quote the user's words in `evidence`. This record is the only place that these decisions survive after the session ends.
- A revert or an abandoned approach, with what caused it.
- A unit of work that is complete, with its verification result, for long or unattended runs.

Do not log routine actions or choices that the code already makes obvious.

## How to append

- Create the file with the header row if it does not exist.
- Keep each cell on one line. Replace tabs and newlines in a cell with spaces.
- Append only. Never edit or delete a row. To correct a row, append a new row whose `why` starts with `supersedes <ts>`.
- The first row that a run appends has the phase `start`. Its `decision` names the task, and its `session` names this run. Before you append later in the same run, read the last rows. If another run wrote a `start` row since your last row, write a new `start` row before your next row.

## Before you hand back

Compare the log with what happened in this run. If a decision, a user correction, or a revert shaped the work and has no row, append it now.
