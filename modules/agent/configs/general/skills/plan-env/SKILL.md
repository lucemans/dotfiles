---
name: plan-env
description: Build an HTML page and host it on `plan.env.md` for a human to open. Use for a plan, spec, review, status update, findings, explainer, architecture overview, comparison, or research write-up. Also use to read a plan.env.md link the user pastes.
---

# Plan Env

You write one HTML file, push it, and give the user the URL. A human reads it in a
browser. It is not product code.

**Push.** `plan_env_plan_push` with `files`: `index.html` plus its assets at relative
paths, under 512 KB. The slug is project-prefixed, `[a-z0-9-]{1,64}`:
`myproject-auth-refactor`, not `auth-refactor`. Slugs are one global namespace, and
reusing one adds a revision at the same URL. Build under `.tmp/docs/<slug>/`, and give
the user the returned URL.

**A revision declares the whole question set.** A push that omits a question clears it,
and its answer. Re-declaring the key brings the answer back. Carry every question forward
unless you mean to drop it. This has cost real answers: one document ran to 14 of 14
answered and now sits at 5 of 8. In a follow-up, an answered question goes forward with
its `anchor` inside `details.earlier`. It keeps its answer and leaves the first screen,
and the ledger at the top shows the answer.

**Do not open the page yourself.** No local server, no headless browser, no screenshot. A
push that returns a URL succeeded, and that is the whole check.

Call `plan_env_plan_projects` first and pass `project`, so the document joins an existing
project instead of a near duplicate. Pass `tags`, a `title`, and `questions` for each
decision the reader owes you.

**`anchor`** is an element `id`, and the answer card becomes its next sibling. Anchor a
question where its case has been made, usually the closing paragraph of the section that
sets the decision up. Never a block of questions at the end, and never a question the
reader cannot answer yet.

**A marker** tints the words a question is about. Give every open question one. Wrap the
words in `<span data-planenv-q="KEY">` with that question's `key`. The viewer tints,
numbers and links the span, and a click jumps to the answer card. Mark the phrase that
names the decision, never a sentence or a heading, once per question. A span whose key
this revision does not ask stays prose.

```html
<p>I put them in the <span data-planenv-q="S2">supported language map</span> between
<code>nix</code> and <code>bash</code>.</p>
<p id="S2-case">Ordering is by priority, read top to bottom.</p>
```

No class, no superscript, no styling: the viewer draws every mark it owns.

**Read.** `plan_env_plan_read` takes a URL or slug and returns `html`, `text`, `outline`
or `a11y`. `.../rev/2` pins a revision, and `plan_env_plan_info` returns the index.

**When not to.** A short answer belongs in the terminal. Build a page when the content is
long, structured, visual, or read more than once.

## Revisions

A push to an existing slug is a revision. Before you write it, name its kind, the same
way you name the shape. Read `plan_env_plan_answers` and the last revision first.

| Kind | When | The top of the page | The earlier revision |
| --- | --- | --- | --- |
| **fix** | A correction. The reader has nothing new to do | Unchanged | Edited in place |
| **follow-up** | Answers came in or the work moved, and one to three decisions are new | Status, open decisions, ledger | Folded |
| **settled** | The reader picked one of several options | The pick, written as the page | Folded: the comparison and every option not picked |
| **rewrite** | The plan changed, or the top needs more than its budget | A new document of its shape | Dropped. The revision list keeps it |

**The top** of a follow-up is everything above the fold. It has no heading of its own,
because the reader is already reading the document. In this order it holds the `h1`, a
`p.rev` line under it such as "Revision 4, follow-up", one status sentence, each open
decision as a `section.open` with its case, then the ledger. It may sit on the canvas or
in a `.block`. Its budget is about 350 words and three open decisions.

**The ledger** is a `ul.ledger`, one `li` per decision: a `.ref` ID and the decision in a
few words, the answer, and the status as a `.dot` and a word, such as applied or not
applied. No header row, no question key, no full prompt. It replaces the answered cards
on the first screen.

**The fold** is one `details.earlier` after the top, closed. Its summary names the
revision it holds, `<summary><span class="sum"><b>Revision 1</b><span>one line on what is
inside</span></span></summary>`. It holds that revision shortened to what still matters,
and corrected where the work changed a fact. The revision list keeps the full text. The
rail lists the top's sections first with no group
label, then a `.history` group labelled with the same revision name. This script lets a
rail link open the fold:

```html
<script>
const reveal = () => {
  const target = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)));
  const fold = target && target.closest("details");
  if (fold && !fold.open) { fold.open = true; target.scrollIntoView(); }
};
addEventListener("hashchange", reveal);
reveal();
</script>
```

## 1. Pick the shape first

The shape decides the spine, and a wrong shape is why a page fights its content.

| The ask sounds like | Shape | Reader's job | Spine | Skip |
| --- | --- | --- | --- | --- |
| "plan this", "how should we build X" | **plan** | accept or reject each | proposals in execution order | fake findings |
| "review this", "what is wrong with X" | **review** | fix or dismiss each | findings, worst first | unasked proposals |
| "what next", "catch me up" | **status** | pick the next move | state, then next actions | IDs, index, counts |
| "explain X", "how does X work" | **explainer** | build a model | the system's structure | task-list language |
| "A or B", "which approach" | **comparison** | choose one | one wide table, then the pick | a section per option |

1. **Write the reader's job in one sentence to yourself before any markup.** Every layout choice answers to it.
2. **If the job is to choose, the choice is countable on the first screen.**
3. **One spine per page.** Mixed asks get one dominant shape. A session changelog is a status document, not a section of a review. "Review this and tell me what to do next" is a review that closes with next actions, and a second spine that is real work becomes its own document. A page that ran six spines ran to 10,021 words.

## 2. Scale the machinery to the content

Below a threshold these are noise, and a model that adds them anyway invents items to
justify them.

| Content size | Turn on |
| --- | --- |
| under ~6 items, under 2 screens | headings and prose. No IDs, index or rail |
| **over 2 screens** | **`nav.toc` in the rail. Mandatory, not a judgment call** |
| 6 or more items | a short ID per item, its anchor `id` and cross-reference |
| 12 or more items | an index table at the top: ID, kind, one line |
| **over ~20 items** | **split the document, or triage it down** |
| counts answer the first question | a counts strip, one number per kind |
| **over 3 files, or a blast radius question** | **a `.tree`, per `reference/tree.md`** |
| any file tree | file type icons, one per row, from `icons.svg` per `icons.md` |
| any code, terminal or proposed change | `figure.snippet` per `snippets.md`, plus `code.css` and `code.js` |
| the reader owes a decision | `questions`, anchored to an `id` |

Past roughly 20 items a page either splits into two documents or triages: the items the
reader must act on stay items, and the rest becomes counted rows in one table. Verbosity
here is item count times a fixed 131 to 185 words per item, so item count is the only
lever that reaches page length.

4. **IDs are free-form.** One letter per kind plus a number: `P1` proposal, `D2` decision, `F1` finding. Name each kind where it appears, and keep it stable across revisions.
5. **Classify an item by what the reader must do with it**, not by which file it touches. An error to fix, a contradiction to resolve and an observation needing no action are three jobs. An explainer has no kinds.
6. **Order for reading.** Execution order when the work is sequenced, worst first when the reader triages, the system's own structure for an explainer. Link dependent items.

## 3. Stylesheet and components

Name the components before you write any markup, the same way you named the shape.

Upload `reference/document.css` verbatim beside `index.html` and link it. It carries the
tokens, the layout and every component below. Do not retype it or invent parallel class
names. Page rules go in a `style` block after the link, and the skeleton is
`body > div.page > (nav.toc + main)`.

**Surfaces.** The page is a slate canvas. Content sits on the canvas, or in a `.block`,
a white surface that groups related sections. Use a block where grouping helps the
reader, for example one for the top and one per group of the spine. Never a block per
section, and never one block for everything. Inside a block nothing is a surface:
sections split by space and a hairline, and tables, code, trees and counts sit on the
raised token. An open decision is the only tinted thing on the page.

**Type.** Three sizes, from tokens: `--fs-title`, 18px, for the `h1`. `--fs-body`, 14px,
for body, headings, tables, the rail and code. `--fs-small`, 12px, for labels, meta and
captions. Never set another size, and nothing is smaller than 12px.

**Themes.** Five palettes, one per document:

- `round`, the default: a slate canvas, white blocks and theme-round's status hues. It needs no attribute.
- `black`, true black and white, the look before round.
- `neutral` for a long read.
- `ink` for an explainer or a research write-up. One accent, a signal red on `--neg`, and the other four hues collapse to the ink, so status reads from its label and never from its colour. A page that triages by hue picks another theme.
- `native` for a status or a walkthrough.

`round` lives in `document.css`. The other four live in `reference/themes.css`, which
redeclares only the tokens. Opt in with `data-theme` on `html`,
`<html lang="en" data-theme="ink">`, and upload `themes.css` linked third.

**The viewer's chrome.** A fixed cluster floats over the top of the page, the way back on
the left, the revision list and Share on the right. It publishes `--planenv-chrome-h`,
`--planenv-tools-w` and `--planenv-brand-w`. `document.css` already offsets the page and
the rail by `--planenv-chrome-h`, and hands its palette to the chrome and the answer card
through `--planenv-chrome-*` and `--planenv-q-*` on `:root`. A page with its own top bar
reserves the space instead of being covered: put `<span data-planenv-slot="tools"></span>`
in that bar, `"brand"` for the left end. Never style the chrome or the card directly: the
variables are the whole interface.

| Class | Use |
| --- | --- |
| `.page` | The grid. The rail at the left edge plus content, above 70rem |
| `.block` | A white surface on the canvas that groups related sections |
| `section.open`, `.open-head` | An open decision. Tinted; `.open-head` holds its `.chip`, `h2` and a `.tag` reading open |
| `nav.toc` | Contents rail. One unlabelled `div` for the current content, a `.history` `div` with a `strong` name for a folded revision. Each `a` holds an `em` ID or a `.dot`, a `.rl` label, and a trailing `.r-tag` or `.r-n` |
| `.meter` | Rail status. One `.track` of hue `span`s sized by `flex`, then one `p` line |
| `.rev` | The revision line under the `h1` |
| `.chip`, `.ref` | An ID in its hue, and the same ID as an inline link to its item |
| `.badge`, `.dot` | An inline status tag, and a status dot beside a word |
| `ul.ledger` | Decisions taken, one row each. See Revisions |
| `.counts` | Counts strip. `b` the number, `span` the label |
| `.tablewrap` > `table` | Any table. The wrapper owns the scroll |
| `td.id`, `td.sz`, `td.num`, `tr:target` | Index columns, a small number, and the jumped-to row |
| `.pbar` > `i` | A proportion bar in a table cell, `i` sized by `width` |
| `.list` > `article` | Many items, hairline separated, with `id` and `:target` |
| `.panel` | One unit the reader accepts or rejects, on the canvas |
| `.split` | Two things compared side by side |
| `.tree`, `.tree.gutter` | Which files a change touches. See `tree.md` |
| `.legend` | Names a hue binding |
| `ul.sources` | A citations list. No bullet, a label per entry |
| `figure.shot` | A screenshot. Full width image, `figcaption` in `.meta` |
| `details.earlier` | The fold. See Revisions |
| `.lede`, `.meta`, `.where`, `.soft`, `.ok`, `.bad` | Standfirst, metadata, a `path:line`, muted prose, pass, fail |

7. **Use the components, or the page comes out flat.** Reach for the class before writing a `div`.

## 4. Color

8. **Every hue you assign means one thing, and keeps it page-wide.** `document.css` names six: `--accent` change, proposal and modified; `--pos` added or passing; `--neg` removed or failing; `--warn` open, and nothing else; `--note` context; `--move` renamed. A modified file is never amber or red. Each `.hue-*` class also sets `--h-500` for dots and bars. Six hues for six kinds of item is fine, six because the page felt flat is not. Syntax highlighting is outside this.
9. **Name the binding where the reader first meets it.** A `.legend`, a chip, or a sentence. An unexplained color is decoration.
10. **Signal a thing once.** An item with a colored chip needs no colored edge and tinted fill as well.
11. **Both themes AA or better.** Check dark before delivering.

## 5. Document design

12. **No em-dash and no middle dot anywhere.** Not in headings, body, tables, code or the title, and not `&mdash;` or `&middot;`. Comma, colon, full stop, or rewrite the sentence. Quoted file content keeps its own characters.
13. **Short sentences, one idea each.** Simplified Technical English, no metaphor. Cut the frames. No "The change:" or "Cost:" opener. No sentence that announces the next table. No header row over rows that already say what they are. No fact told twice, once in prose and once in a table. Keep the number and drop the narration around it. Put the `path:line` inside the claim it supports, and drop quoted code that only decorates.
14. **Not a landing page.** No hero, feature grid or emoji, and never a metric, score or badge the work did not produce.
15. **Every path, symbol, flag and command in `code`**, and metadata in its component: `.meta` a standfirst, `.where` a `path:line`, `th` a column head.
16. **A surface never contains a surface.** A `.block` or a `.panel` is the only white surface, and it sits on the canvas. Nothing inside it carries its own white fill or panel radius. Code, tables, trees and counts take the raised token. A `.panel` is one unit the reader accepts or rejects, never inside a block, never inside another panel. Many small items go in `.list`.
17. **Table for repeated fields, prose for the rest.** A one-column table is a list, every table sits in `.tablewrap`, and one large numeral only in `.counts`.
18. **Specific element before `div`.** `<del>` and `<ins>` diff lines, `<samp>` output, `<kbd>` keys, `<code>` paths, `<dl>` label and value pairs, `<article>` an item the reader acts on.
19. **Style `:target`, keep heading levels in order, and keep the current content visible.** The one fold is `details.earlier` in a follow-up or settled revision, per Revisions. No other collapsible unless the user asked for it.
20. **No fake screenshot built from `div` elements, and no hand-rolled SVG path data.** A real image goes in `figure.shot`, a file tree in `.tree`.

## 6. Content fidelity

21. **Quote the source exactly.** Never paraphrase a line and present it as a quotation.
22. **Cite `path:line`, and name the real symbol.** Not "the auth middleware" but `requireSession()` at `src/auth/session.ts:41`.
23. **Give the complete content.** No "and so on", no "for brevity", no `// ...`. Untouched siblings in a `.tree` get a counted `.row.rest` line, a fact rather than an ellipsis. A fold that shortens an earlier revision is not truncation, because the revision list keeps the full text.
24. **State what is not done, not verified or not applied**, in the page, not only in chat. On a page carrying faults and fixes, every fault says whether it is still true.
25. **Show a proposed file change as a diff.** `figure.snippet.is-diff` per `snippets.md`, headed with the path, the line range, and whether it adds, replaces or deletes. Quote removed lines exactly from the file, or say you have not read it.
26. **Show which files a change touches as a `.tree`** once the count passes three, near the top. It answers the blast radius question that prose about "the auth layer" cannot.
27. **Name the thing, do not point at it.** Every paragraph names its own subject, with the `path:line`, even when a heading or a chip above said it. "It says the file is inlined" fails. "A comment at `reference/code.js:1-5` still tells the reader to inline the file" works.
28. **A cross reference says what is at the other end.** Not "which S3 ends" but "for `is-diff`, see the change I propose in S3". Write the ID itself as a link in its hue, `<a class="ref hue-plan" href="#P3">P3</a>`.
29. **Say what you checked, in your own voice.** "I loaded both grammars in a probe page and checked they render", not "Both grammars load and render". The second cannot be told from an assumption.

## 7. Per-shape notes

**plan.** Proposals in execution order, each with what changes, why and what it costs.
Mark what you are not proposing. Open with the decision the reader owes you.

**review.** Findings worst first, severity bound to a hue per rule 8. Each finding: the
`path:line`, what breaks, the concrete failure. Separate "must fix" from "worth
considering". Mark each one fixed or still live, and say what you did not review.

**status.** Narrative, not a queue. Where the branch is, what landed, what is in flight,
what blocks. End with next actions, each one startable today. No IDs, index or counts.

**explainer.** The system's own structure. Lead with the shape of the thing, a diagram or
a table, then the parts. Name every identifier as `code`, and skip task language.

**comparison.** One wide table, options as columns, criteria as rows ordered by weight.
Fill every cell, then name the criterion that decided. After the reader picks, the next
revision is settled: the pick is the page, and the table moves into the fold.

A mockup or a UI sketch is the `plan-env-design` skill's job. This skill is for a
document.

## 8. Reference files

Do not reinvent their contents per document.

- **Always:** `document.css`, verbatim and linked. Tokens, layout, every component in section 3.
- **A non-default theme:** `themes.css`, linked third.
- **Code, diffs, terminals:** `snippets.md`, with `code.css` and `code.js` uploaded and `code.css` linked second.
- **File trees:** `tree.md`. Its CSS is in `document.css`.
- **Icons:** `icons.md`, with `icons.svg` for the file type symbols.
- **Charts, inline scripts, pinned imports:** `interactive.md`.

Upload every stylesheet, script and image as a sibling, so the revision pins it. The
sprite is the exception: `use href="sprite.svg#id"` does not resolve across files in
Chrome or Safari, so copy the `symbol` elements the page uses into a hidden `svg` in the
body. Page CSS and a small script stay inline too.

No web font, and no script or stylesheet from another host. External requests are pinned
`https://esm.sh/` imports only, because revisions are permanent.

## Before you deliver

- [ ] Shape named, and one spine
- [ ] `document.css` uploaded verbatim, linked, and its classes used
- [ ] No page CSS adds a third radius, a fourth type size, text under 12px, a centred column, a gradient or glass, an outline around a surface, or motion
- [ ] Past two screens: `nav.toc` in `.page`, in document order
- [ ] Items carry a `.chip` in their hue, an `id`, and a visible `:target` state. Every mention of an ID elsewhere is a `.ref`
- [ ] No em-dash or middle dot anywhere in the file, outside quoted file content
- [ ] No paragraph leans on `It` or `This` for its subject
- [ ] `color-scheme: light dark`, both schemes readable, and `data-theme` absent for round or one of `black`, `neutral`, `ink`, `native` with `themes.css` linked third
- [ ] Every hue means one thing, it is named, and nothing is signalled twice
- [ ] No surface inside a `.block` or `.panel`, no block per section, and no single block around everything
- [ ] Machinery matches the size, and over ~20 items the page split or triaged
- [ ] Every file claim cites `path:line`; changes are diffs with exact removed lines
- [ ] Any tree: folders above files, a `.row` class per status, a `.legend`, a counted `.row.rest`, the gutter
- [ ] Every `use href` resolves to a `symbol` here; every snippet names its language in `data-lang`
- [ ] Nothing truncated or placeholdered, no emoji, no marketing voice, no invented metric
- [ ] Assets uploaded as siblings; external requests are pinned esm.sh imports only
- [ ] `questions` cover every decision, the last set is carried forward or dropped on purpose, and in a follow-up the answered ones are anchored in the fold
- [ ] Revision kind named. In a follow-up, the top has no heading of its own, a `.rev` line under the `h1`, and fits its budget. The fold and its rail group carry the revision's name
- [ ] Every open question has one marker: a `span` carrying only `data-planenv-q`, around a phrase
- [ ] No browser, server or screenshot was used on this page
- [ ] The user has the plan.env.md URL
