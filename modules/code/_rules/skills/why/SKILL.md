---
name: why
description: "Use for 'why does X work this way', 'why we picked Y', design rationale, regressions, or where a magic number came from. Works the repository's historical record (commit history, PR and issue discussion, in-repo prose, tests) from several angles in parallel, then returns a cited, confidence-calibrated read on the decision and its tradeoffs. Use how for runtime behavior."
---

# Why

Investigate the motivation and intent behind code. Why was it built this way? What edge cases were considered? What product, business, or operational constraints shaped the design? What alternatives were rejected, and why?

Companion to the `how` skill. `how` answers what the code does and how it works. `why` answers what forces led to its shape.

## How this skill works

The repository is the whole searchable record. Commit history, PR and issue discussion, inline comments, tests, ADRs, and CHANGELOG entries are where rationale survives, and each of those holds a different kind of it: a commit says what changed, a PR thread says what was argued, a test name says which edge case forced the shape, a comment says what the author feared. You cannot predict from the question alone which one holds the answer, so the skill works several angles in parallel, then synthesizes with explicit confidence calibration.

Null results are first-class evidence; report them alongside positive findings. Distinguish two kinds, because they license different conclusions. A search that ran and found nothing tells you the rationale was not written down where you looked. Rationale that only ever existed in conversation is unrecoverable from here, and its absence says nothing about whether the decision was considered. Never let the second look like the first.

## Operating Posture

Operate as a careful, cautious, precise investigator. Think like a detective piecing together a historical case from fragmentary records. When the record is thin, say so.

Concretely:

- **Evidence before narrative.** Collect the pieces first, then see what story they support. Never pick a story and recruit the evidence that fits it.
- **Precision over polish.** Prefer the exact quote and citation over a smooth paraphrase. A reader should be able to follow any claim back to its source and verify it in under a minute.
- **Consider what you haven't seen.** The evidence you find is a sample, not the whole truth. Before concluding, ask what you would expect to see if an alternative explanation were true, and whether you looked for it.
- **Name the gaps.** If a thread goes cold, a source isn't searchable, or a question has no answer, document the gap. Don't paper it over with an authoritative-sounding guess.
- **Hedge on purpose.** When evidence is indirect, your language should signal it ("appears to", "likely", "suggests"). Confidence-matching phrasing is a feature of the output, not a stylistic choice the synthesizer may override.
- **No shortcut by code-reading.** The code tells you what it does, rarely why it exists. Resist inferring intent from code shape.

This posture is the working method, not a disclaimer.

## Core Epistemics

This skill builds a **patchwork understanding** from fragmented historical evidence. Tickets go stale. Chat threads get deleted. Commit messages lie. People change their minds between the PR description and the implementation. The original author may have left the company.

Be ruthlessly honest about what you know versus what you're inferring. The goal is not a satisfying story; it is to surface evidence, calibrate confidence, and let the user decide.

Principles:

- **Cite everything.** Every claim about intent should reference a specific commit hash, PR number, ticket ID, doc URL, chat permalink, or code comment. If you can't cite it, it's inference, not fact, and must be labeled as such.
- **Prefer "appears to" over "because".** Hedge when evidence is indirect. Reserve confident language for direct, explicit evidence.
- **Surface contradictions.** If two sources disagree, show both. Don't quietly pick the one that fits your narrative.
- **Acknowledge gaps.** If a question has no answer in any source you searched, say so. An honest "we couldn't find out why" beats a confident guess.
- **Multiple hypotheses are valid.** When the evidence fits several stories, present them all with the evidence for each. Let the user triangulate.
- **Beware rationalization.** Code that makes sense today may have been written for reasons that no longer apply, or for no good reason at all. Don't retrofit intent.

Read `references/epistemics.md` for the full confidence framework and phrasing guide. The synthesizer must follow it.

## Step 1. Understand the Target and the Question

Parse what the user is asking. The **target** is usually a chunk of code, a pattern, a feature, or a named design decision. The **question** is usually one of:

- "Why was X designed this way?" Design rationale.
- "Why do we do X instead of Y?" Tradeoff or alternatives.
- "What edge cases motivated this?" Defensive reasoning.
- "What business or product constraint led to this?" External forcing function.
- "Why does this code still exist?" Dead-code territory.
- "What's the history of X?" Broad archaeological sweep.

If the target is vague ("why do we do it this way?" with no clear referent), make your best guess from conversation context: the files open in this session, recent edits, what was just discussed. State your interpretation briefly so the user can redirect if you're off, then proceed.

## Step 2. Establish the Code Anchor

Before spawning investigators, anchor the investigation in concrete code. You need:

- The relevant file path(s) and line range(s)
- The key symbols (function names, class names, constants)
- An initial commit list. The last few commits touching the target.
- PR numbers from merge commits (pattern `(#1234)` in the subject line)

Build this inline. It's cheap, and every investigator needs it.

```bash
# Blame target lines for last-touch commits
git blame -L <start>,<end> <file>

# Full file history, with patches, through renames
git log --follow -p -- <file>

# Last N commits touching the file, PR numbers visible
git log --oneline -20 -- <file>

# Extract PR numbers from a commit message
git log -1 --format=%B <commit>
```

Pull PR bodies and discussion via `gh` for any substantive commits:

```bash
gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews
```

Capture this as seed context (file paths, symbols, commits, PR numbers, linked ticket IDs). Pass it to the investigators so they don't rediscover it.

## Step 3. Spawn Parallel Investigators (default posture)

Each angle reads the same repository through a different lens, and you cannot tell from the question alone which lens catches the answer. So run them in parallel by default.

Spawn 2 to 4 investigators in a single message. Each gets:

1. The base prompt from `references/investigator-prompt.md`
2. The query vocabulary in `references/code-archaeology.md`
3. Its assigned angle from the roster below
4. The code anchor from Step 2 (file paths, symbols, commit hashes, PR numbers, issue IDs)
5. The user's original question

Investigators read and report. They never edit a file, and they never mutate git state: no staging, committing, checking out, or branch switching. Reading history is the entire job, and `git log`, `git blame`, `git show`, `git diff`, and the read-only `gh` subcommands cover it.

### Investigator roster

Spawn the first three by default. Add the fourth when the target looks like an instance of a repeated pattern rather than a one-off.

1. **Commit and diff history.** `git log --follow`, pickaxe searches with `-S` and `-G`, `git blame`, `git show` on each substantive commit. Best at surfacing *when the shape changed and what changed with it*. The commit that introduced a constant, the commit that reverted an earlier approach, co-changed files that reveal the real unit of work, and commit messages that name an incident or issue. Weakest at motivation: a diff shows the change, rarely the reason.

2. **PR and issue discussion.** `gh pr view` with `--json body,comments,reviews`, `gh issue view`, `gh pr list --search` and `gh issue list --search` on the symptom rather than the fix. Best at surfacing *rationale captured while the change was argued*. PR descriptions that state the problem, review threads debating alternatives, an issue whose report predates the code and whose close references the PR. Usually the richest angle when the repo uses PRs seriously.

3. **In-repo prose and tests.** Inline comments, TODO and FIXME notes, docstrings, ADRs, README and CHANGELOG entries, and test names and assertions. Best at surfacing *the constraint the author wanted the next reader to know*. A test named for the edge case that forced the branch is direct evidence of motivation; a comment explaining a vendor quirk is often the only record of it.

4. **Pattern origin.** Where the pattern first appears in the codebase and what motivated it *there*. Best at answering "why is it written this way" when the honest answer is that it was copied. Trace the pattern back to its earliest instance and investigate that commit instead; the target may carry no independent rationale at all.

### When the record runs out

There is no ticket tracker, chat archive, observability platform, error tracker, or analytics warehouse in this environment. The repository is the whole record.

That is a boundary, not a gap you can close by searching harder, and it changes what a null result means. If the rate limit is 100 and no commit, PR, issue, comment, or test says why, the honest finding is that the reason never reached the repository, not that there was no reason. Say exactly that. A confident "the value appears arbitrary" is the failure mode this skill exists to prevent.

You may answer inline without spawning investigators only when the code anchor from Step 2 already contains the complete answer, such as a single commit whose PR body states the rationale outright. Say that you did so. This should be rare.

## Step 4. Synthesize

Spawn one synthesizer subagent, on the strongest reasoning model available. Its quality check spot-verifies citations against the repository and `gh`, so it needs the same read access as the investigators.

The synthesizer gets:

1. The investigator findings, including any null results and any categories skipped with justification
2. The code anchor from Step 2 (file paths, symbols, commit hashes, PR numbers, ticket IDs)
3. The user's original question
4. The epistemics framework from `references/epistemics.md`
5. The synthesizer prompt template from `references/synthesizer-prompt.md`

Its job is the final output: a confidence-weighted, evidence-cited narrative with clearly separated "what we know" and "what we're inferring" sections, plus honest acknowledgment of gaps and null-result sources.

## Step 5. Present

Take the synthesizer's output and present it to the user. You may lightly edit for clarity or add context from the conversation, but **do not rewrite the confidence language**. The epistemic framing is the product. Dropping the hedges to sound more authoritative is the exact failure mode this skill exists to prevent.

## Output Format

The final output uses this structure. Adapt as needed, but keep the confidence separation intact.

**The Question**. Restate what the user asked, concisely.

**The Code in Question**. File paths, line ranges, and key symbols. One or two lines so the reader is anchored.

**What We Found (direct evidence)**. Claims with explicit citations (PR #, ticket ID, doc URL, chat permalink, commit hash, code comment with file:line). Each bullet is a thing we have textual evidence for. Use present tense and quote or paraphrase the source.

**What We Can Reasonably Infer**. Claims well-supported by indirect evidence or combinations of signals, but not explicitly stated anywhere. Each bullet must explain the inference chain: "Given A and B, it's likely that C." Use hedged language ("appears to", "likely", "suggests").

**Competing Hypotheses**. If the evidence fits multiple stories, list them. For each, give the hypothesis, the evidence for it, and the evidence against it. Don't force a winner when the record doesn't support one. (Skip this section if there's a clear answer.)

**What We Don't Know**. Explicit gaps. Questions the user asked that the evidence didn't answer. Sources we searched and came up empty. Be specific. "We searched the issue tracker for 'rate limit' and found no ticket discussing this specific threshold" is more useful than "we don't know why."

**Searches Run**. One line per angle, including the ones that returned nothing, so the user can judge coverage and redirect if something obvious was missed.

Format each line as: `- <Angle>: <what was searched>. <what was found, or "nothing bearing on the question">.`

Example:

- Commit and diff history: `git log --follow -p backend/retry.ts` (14 commits, 2023-04 to 2025-01), `git log -S 'maxAttempts'`. Found commit `a3f21c0` introducing exponential backoff, message references issue #221.
- PR and issue discussion: `gh pr view 340`, `gh issue view 221`, `gh issue list --search 'timeout'`. Issue #221 reports upstream 5xx storms; PR #340 review thread debates fixed delay versus backoff and settles on backoff.
- In-repo prose and tests: searched comments and tests referencing `retry`, `backoff`, `maxAttempts`. Test `retries until the upstream stops 503ing` names the motivating case; no comment explains the value 5.
- Pattern origin: not investigated. The retry helper is the only instance in the repo.

Close with the boundary: the repository is the entire searchable record, so rationale that stayed in conversation is unreachable.

After the Sources Consulted block, if the user's `why` question is a precursor to actually changing this code, convert the lineage findings into a Preserve / Change / Avoid / Risk constraint set suitable for planning the change.

When the answer is long enough to be read more than once, or the coverage map matters as a reference, deliver it as a findings page through the `plan-env` skill and keep the section structure above.

## Common Failure Modes to Avoid

- **Confident storytelling**. A plausible narrative built from thin evidence. A bullet with no citation goes in "inferred" or "hypotheses," not "what we found."
- **Citing the code as evidence for its own intent**. "Handles the null case because it checks for null" is mechanics, not motivation. Motivation comes from an external source (PR discussion, ticket, comment, conversation) or is labeled as inference.
- **Recency bias**. Assuming the most recent commit is authoritative. The current shape is often the accretion of many earlier decisions. Trace back.
- **Sycophantic agreement**. If the user suggests a reason ("I assume this is for performance?"), treat it as a hypothesis and check the evidence independently, don't just confirm it.
- **Skipping the gaps section**. An honest accounting of what you couldn't find out is part of the value.
- **Skipping an angle by anticipation**. Deciding up front that "the tests won't say anything" without looking. A null result is a data point; a skipped search is a blind spot.
- **Reading a missing record as a settled answer**. Nothing in the repo explains the threshold, so the threshold was arbitrary. That does not follow, and it is the specific error this environment invites, because the repository is the only record there is.
- **Collapsing investigators into one agent**. Each angle has its own query vocabulary and pitfalls; pooling them dilutes the search and makes coverage harder to judge.

## Reference Files

- `references/code-archaeology.md`. The git and `gh` query vocabulary every investigator works from, including the incident hunt for defensive code. Append it to each investigator prompt.
- `references/epistemics.md`. Confidence tiers and phrasing guide. The synthesizer must follow it.
- `references/investigator-prompt.md`. Base prompt template for investigator subagents.
- `references/synthesizer-prompt.md`. Prompt template for the synthesizer subagent, including the output format.
