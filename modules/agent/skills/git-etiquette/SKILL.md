---
name: git-etiquette
description: Luc's commit subject and PR title style. Use before writing a commit message, opening or retitling a pull request, or writing a PR body.
---

# Git etiquette

A PR title lands as the commit subject when Luc squashes it, so a PR title follows the same rules as a commit subject.

## Subject and PR title

1. Start with one verb: Fix (a bug), Introduce (a new feature; Add also works), Implement (a new mechanism), Improve (better existing behaviour) or Update (changed existing behaviour). Remove or Drop for a deletion.
2. After the verb, name what changed as a noun phrase, then where it lives, so the subject makes sense to someone who only reads the log. Not the mechanism, not the reason.
   - The place is a part of the app (`in sidebar`, `in composer`, `in transcript`, `in question card`, `in model picker`, `in settings`, `in side panel`, `in land tui`, `in runner`, `in k5c`), or the harness it is for (`for omp`, `for codex`, `for omp and codex`).
   - Leave the place out only when the noun already says it: `Fix runner restart continuations`, `Introduce codex app-server session`.
3. At most 8 words and 60 characters.
4. No article (a, an, the) and no clause word (when, after, until, without).
5. Only the first letter is a capital. Write pr, ui, cli, api, json, git, nix and omp in lowercase.
6. No colon, comma, "&", brackets or final period, and no "and" except in the place (`for omp and codex`). Two changes in one title: name the area they share.
7. No issue or PR number. `Closes #n` goes in the body.
8. One line.

| Not this | This |
|---|---|
| Show a model card on hover of every model mark | Introduce model hover card in transcript |
| Keep typed text when sending or picking a completion | Fix text entry completion in composer |
| Composer: one placeholder for idle and steer, follow-up instead of queued | Update composer placeholder |
| Record PR landings in atomic git pushes | Implement atomic pr landing records |
| Fix bare diff previews | Fix bare diff previews in question card |
| Introduce update mark | Introduce update mark in sidebar |
| Introduce sticky picker headings | Introduce sticky headings in model picker |
| Implement pending message handling | Implement pending messages in composer |

## Changelog entry topic

The `topic` of a changelog entry follows the same idea: what changed and where, readable without the PR, such as `Diff previews in question card`, `Repositories added to a chat` or `Update mark in sidebar`. Not `chat repositories` or `Update mark`.

## PR body

Short. What changed, how it was checked, screenshots for anything visible. No essay, no restating the issue, no list of every file.

A change anyone can see gets before and after screenshots of the same view, in light, dark and at phone width. Take the before shots on the base branch, not from memory. Only after shots is not enough.

The forge groups screenshots, so do not put them in a table. Write each image as its own paragraph, one after another, with no text between them. Name the files `<view>-<before|after>-<light|dark>.png`, and `<view>-<before|after>-mobile.png` for the phone. Files whose names differ only by those words become one view: before and after as a split, light and dark as a toggle. A line of text between images starts a new group, so use one to name the next view.

A terminal UI has no phone view. Its narrow shot is a terminal about a third of a screen wide, such as 80 columns.

A change that relies on a feature of a specific harness or integration version (omp, Codex, Claude Code, CLIProxy, k5f, metered-usage) adds a `range:` line to its changelog entry, such as `range: omp 18.11 to 18.12`, so the release states which versions it supports.
