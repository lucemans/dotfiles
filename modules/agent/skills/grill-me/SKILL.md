---
name: grill-me
description: "Interview the maintainer about a project idea in batches of questions, push back, then write spec/goals.md, spec/design.md, the first milestone's issues and a scaffold PR. Use when the maintainer brings an idea, a plan or a new repo and says 'grill me', 'interrogate me' or 'plan this'."
---

With a question tool, run the whole interview in this one turn: ask, read the answers, ask again, write. Do not end the turn to wait for the maintainer.

## Before the first question

- Read what exists: the idea, the repository (README, `spec/`, code), and any issue the chat works on. Never ask what these already answer.
- If `spec/goals.md` or `spec/design.md` exists, extend it. Keep every line the maintainer wrote.
- List the open decisions under these topics, in this order: Goal (what and for whom), Scope (what is in and out), Interfaces (what he sees and types), Data, Stack, Risks, Checks (how we know it works).
- Decide yourself whatever is cheap to change later, such as names, layout or formatting. Mark it "agent's pick" and do not ask about it.

## Asking

- Ask with the `ask` tool, one call per batch. In another harness, use its question tool the same way. With no question tool, write the batch as a numbered list with your recommendation for each, end the turn, and go on when he answers.
- A batch is, in this order: the pushback and follow-ups the last answers earned, then questions on one topic. At most 5 questions in all. Merge two small topics rather than send one question alone.
- Set every question's `header` to its topic's name.
- Begin the first question of each batch with the number of topics that have had no question yet, this batch's included, as in "(4 topics left)". In the first batch, add: "Answer 'decide the rest' at any point and I will decide what is left."
- Ask one decision per question, in one or two sentences. Say why it matters when that is not obvious.
- If another answer in the same batch decides a question's options or their descriptions, move that question to the next batch.
- Give 2 to 4 options. The `label` is the choice in a few words; the `description` is what it costs or rules out.
- For Interfaces questions whose options would look different on screen, and when the `plan-env-design` skill is installed, put every option's screen in one design document for the whole interview: one slug, each screen under its own heading, finished, with real copy and plausible data, not a wireframe. Push a new revision of that document before you ask, and link each option's `description` to its heading. Never one document per option or per question.
- Set `recommended` on every question but a contradiction, and start that option's description with the reason. For a `multi` question, say in the question which set you recommend.
- Base the recommendation on what he said and what the repository shows. If he named a preference, recommend it. Never recommend an option that breaks one of his earlier answers.
- Do not add an "Other" option. He can always write his own answer.
- Use `multi` only when several options can hold at once.

## Reading the answers

- Read each chosen option together with its note. A note that narrows the option wins. A note that breaks the option is a contradiction; see below.
- His own answer replaces the options. If it is vague, follow up in the next batch with concrete readings of it as options.

## Pushing back

Open each batch after the first with the pushback the last answers earned:

- A risk he did not name: say it in one sentence, then ask whether to accept it or take your safer option.
- A cheaper path to the same goal: offer it as an option and recommend it, with the cost difference.
- A contradiction, with an earlier answer or inside one answer (an option and its note): quote both sides, call it a contradiction, and ask which one holds. Never settle it yourself, and leave this question without `recommended`.
- Scope bigger than a first milestone: propose the cut and ask.

Push back once per point. If he keeps his answer, record it as "(maintainer)" and move on.

## When to stop

Stop asking, without asking whether to stop, when any of these holds:

- Every topic has had at least one question, and he took every recommendation of the last batch without a note.
- He says "decide the rest", "enough" or the like, in an answer, a note or a message.
- You have asked 8 batches.

Then decide every open decision yourself and mark each one "agent's pick".

## What you write, in this order

1. **`spec/goals.md`**: the goal, the users, what must work and what is out, from his idea, his own answers and his notes only. An option he only accepted is a decision for `spec/design.md`, not a goal.
2. **`spec/design.md`**: the decisions, grouped by topic. Each decision is one line with its reason, ending in "(maintainer)" when he chose or wrote it, or "(agent's pick)" when you decided. A recommended option he accepted is "(maintainer)". Close with the risks you named and what he answered.
3. **Issues for the first milestone**, filed on the forge in build order so the numbers follow it. Each issue is one PR's work and says what to build, what is out, how to check it, and which issue it builds on. Give each a type label and the area labels that fit, from the forge's label list.
4. **A scaffold PR** with the two spec files and whichever of these the repository lacks: a flake with a dev shell, a `checks` output that builds and tests the app, an empty app that builds and runs, and a README of one paragraph. Run `nix flake check` and the app before you open the PR.

Write the spec files in short, plain sentences. No word of the interview goes into them unless it is a decision or a goal.

Without a forge repository, such as in a scratch chat: `git init` the work directory if needed, write the files, commit the scaffold on a branch, and give each issue's title and body in your final message in build order, naming earlier issues by title. Say that you filed nothing.

## The final message

List the files, the issues and the PR, then every "agent's pick" in one line each, so he can overturn any of them with one answer.
