---
name: plan-env
description: Build an HTML page and host it on `plan.env.md` for a human to open. Use for a plan, spec, review, status update, findings, explainer, architecture or feature overview, comparison, research write-up, or UI mockup. Also use to read a plan.env.md link the user pastes.
---

# Plan Env

You write one HTML file, push it, and give the user the URL. The page is read by a
human in a browser, not shipped as product code.

**Push.** `plan_env_plan_push` with `files`: `index.html` plus its assets, each at a
relative path. Under 512 KB. Use a project-prefixed slug matching `[a-z0-9-]{1,64}`:
`myproject-auth-refactor`, not `auth-refactor`. Slugs share one global namespace. Reuse a
slug to add a revision. Give the user the returned URL. Never try to publish beyond this.

**Do not open the page yourself.** No local web server, no headless browser, no
screenshot. A push that returns a URL succeeded, and that is the whole check. To read
back what you sent, use `plan_env_plan_read`, which returns `html`, `text`, `outline` or
`a11y`. The reader opens the page; building a way to look at it first is work nobody
asked for.

Call `plan_env_plan_projects` first and pass `project`, so the document joins an existing
project instead of starting a near duplicate. Pass `tags` and a `title` as well. Pass
`questions` when the reader owes you a decision: each one anchors to an element `id` in
the page and is answered in the page, which is faster for the reader than a reply in
chat.

Anchor a question where its case has been made. A reader decides after your argument, not
before it, so the usual place is the end of the section that sets the decision up,
sometimes the middle of one, and rarely the top. Which element is your judgment, and the
anchor is how you express it. Do not collect every question into one block at the end, and
do not open a page with a question the reader cannot yet answer.

A question has two attachments in the page, and they do different jobs.

**`anchor`** is an element `id`, and it decides where the answer card is placed: the card
becomes that element's next sibling. Give the `id` to the last element of the argument,
usually the closing paragraph, so the card lands under the case rather than inside it.

**A marker** is optional, and it tints the words the question is about. Wrap them in
`<span data-planenv-q="KEY">`, where `KEY` is that question's `key`. The viewer tints the
span, numbers it, and makes it jump to the card. Mark the phrase that names the decision,
never a whole sentence or heading, and mark it at most once per question. A span whose key
this revision does not ask stays ordinary prose, so an old marker left in the page is
harmless rather than a link to nothing.

```html
<p>Both grammars are pinned, and I put them in the
<span data-planenv-q="S2">supported language map</span> between <code>nix</code> and
<code>bash</code> rather than at the end.</p>
<p id="S2-case">Ordering is by priority, read top to bottom.</p>
```

Write nothing else for either. No class, no superscript, no styling: the viewer draws every
mark it owns, and only for the reader who can answer. A visitor sees the page you wrote.

**Read.** `plan_env_plan_read` takes a URL or slug. `.../rev/2` reads that pinned
revision. `plan_env_plan_info` returns metadata and the revision index.

**When not to.** A short answer belongs in the terminal. Build a page when the content
is long, structured, visual, or read more than once.

## 1. Pick the shape first

Name the shape before you write markup. The shape decides the spine, and a wrong shape
is why a page fights its own content.

| The ask sounds like | Shape | Reader's job | Spine | Skip |
| --- | --- | --- | --- | --- |
| "plan this", "spec this", "how should we build X" | **plan** | accept, reject, sequence | proposals in execution order | fake findings |
| "review this PR", "what's wrong with X", "audit this" | **review** | fix or dismiss each finding | findings, worst first | proposals it did not ask for |
| "where is the branch", "what next", "catch me up" | **status** | know where things stand, pick the next move | timeline or state, then next actions | item IDs, index, counts strip |
| "explain X", "visual overview of feature X", "how does X work" | **explainer** | build a mental model | the system's own structure | anything that reads as a task list |
| "A or B", "which approach" | **comparison** | choose one | one wide table, then the recommendation | separate sections per option |
| "sketch this UI", "mock this screen" | **mockup** | look at it and react | the design itself | every design rule in section 5 |

Two rules that survive every shape:

1. **Write the reader's job in one sentence to yourself before any markup.** "Decide which of these twenty proposals to accept." "Understand why the build broke." Every layout choice then answers to that sentence.
2. **If the job is to choose, the choice is countable on the first screen.** A page that buries the decision under its own reasoning failed, however good the reasoning is.

Mixed asks happen. "Review this PR and tell me what to do next" is a review whose last
section is a status. Pick the dominant shape, do not run both spines.

## 2. Scale the machinery to the content

Turn features on at these thresholds. Below a threshold they are noise, and a model
that adds them anyway invents items to justify them.

| Content size | Turn on |
| --- | --- |
| under ~6 items, under 2 screens | headings and prose only. No IDs, no index, no rail |
| **over 2 screens, any item count** | **`nav.toc` in the rail. Mandatory, not a judgment call** |
| 6 or more items | a short ID per item, used as the anchor `id` and in every cross-reference |
| 12 or more items | an index table at the top: ID, kind, one line each |
| several parallel views of one subject | `.tabs`, with a `.tab-link` per view in the rail |
| counts answer the reader's first question | a counts strip, one number per kind, the kind that demands attention first |
| **a change touching more than 3 files, or any question about blast radius** | **a file tree, per `reference/tree.md`** |
| the reader owes you a decision | `questions` on the push, one per decision, anchored to its `id`, optionally marked with `data-planenv-q` |

3. **IDs are free-form and derived from the page.** One letter per kind plus a number. A plan might use `P1` proposal, `D2` decision, `N3` no action. A review might use `F1` finding, `R2` regression. Name each kind where it first appears. Do not force a page into a vocabulary it does not have, and do not invent a kind to fill a column.
4. **Keep an ID stable across revisions** so the user can say "reject P4" in chat.
5. **Classify an item by what the reader must do with it**, not by which file it touches. An error to fix, a contradiction to resolve, and an observation needing no action are three different jobs, and the reader cannot triage until told which is which. An explainer has no jobs, so it has no kinds. Do not manufacture them.
6. **Order for reading.** Execution order when the work is sequenced, worst-first when the reader triages, the system's own structure for an explainer. Group by kind only when the reader faces an unordered pile.
7. **Link items that depend on each other.** If one requires another, say so and link it.

## 3. Stylesheet and components

Name the components this page will use before you write any markup, the same way you named
the shape. A page whose components were chosen after the prose was written comes out as
prose with a stylesheet attached.

Upload `reference/document.css` verbatim beside `index.html` and link it. It carries the
tokens, the full-width layout, and every component below. Do not retype it, do not trim
it, and do not invent a parallel set of class names. Page-specific rules go in a `style`
block after the link.

The page skeleton it expects:

```html
<body>
  <div class="page">
    <nav class="toc">
      <div>
        <strong>Findings</strong>
        <ol>
          <li><a href="#F1"><em>F1</em> Sandbox calls the removed API</a></li>
        </ol>
      </div>
      <div>
        <strong>Packages</strong>          <!-- tab entries, one per view -->
        <ol>
          <li><a class="tab-link" href="#core">core</a></li>
          <li><a class="tab-link" href="#signaling">signaling</a></li>
        </ol>
      </div>
    </nav>
    <main>
      <div class="tabs">
        <section class="tab" id="core">...</section>
        <section class="tab" id="signaling">...</section>
      </div>
    </main>
  </div>
</body>
```

| Class | Use |
| --- | --- |
| `.page` | The grid. Rail plus content above 70rem, one column below, full width at both |
| `nav.toc` | Contents rail, `--rail` wide. `div` per group, `strong` for the group name, `em` for an ID |
| `nav.toc a.tab-link` | A rail entry that swaps the view instead of jumping to a heading |
| `.tabs` > `.tab` | Parallel views. Each `.tab` needs the `id` its `.tab-link` points at |
| `.counts` | Counts strip. One `div` per kind, `b` for the number, `span` for the label |
| `.chip` | Square ID chip, `P1` or `F3`, in a `header` beside the item title |
| `.tablewrap` > `table` | Any table. The wrapper owns the scroll |
| `td.id`, `td.sz`, `tr:target` | Index table: ID column, size column, jumped-to row |
| `.list` > `article` | Many items, hairline separated, each with an `id` and a `:target` state |
| `.panel` | One discrete unit the reader accepts or rejects. Never nested |
| `.split` | Two things compared side by side inside one panel |
| `.tree`, `.tree.gutter` | Which files a change touches, and how. See `reference/tree.md` |
| `.legend` | Names a hue binding where the reader first meets it |
| `.chip`, `.badge` | A square ID chip, and an inline status tag |
| `.lede`, `.meta`, `.where`, `.soft`, `.ok`, `.bad` | Standfirst, small metadata, a `path:line`, muted prose, pass, fail |

Marking the open tab in the rail needs one rule per tab, since CSS cannot match a link
to the element it targets. Write these after the inlined stylesheet:

```css
.page:has(#core:target) .toc a[href="#core"] { color: var(--accent); background: var(--accent-soft); }
.page:has(#signaling:target) .toc a[href="#signaling"] { color: var(--accent); background: var(--accent-soft); }
```

8. **Full width, always.** No `max-width`, no `margin-inline: auto`, no centered column. Content runs from `--pad` on the left to `--pad` on the right, whatever the window is. `--rail` is the only fixed measurement on the page.
9. **One left edge, one right edge.** Prose, tables, diagrams, and code blocks all begin and end at the same two positions. Varying the width per element is what makes a page look assembled out of parts.
10. **Keep paragraphs short instead of narrow.** Three or four lines, then a heading, a table, or a list. A long line is only hard to read when the block under it is also tall.
11. **`overflow-x: auto` is a fallback, not a layout.** A 9-column table fits at 1600px, so give it the room. `.tablewrap` keeps the container so a 900px window degrades instead of breaking, and the body never scrolls sideways.
12. **Use the components, or the page comes out flat.** A page with no `nav.toc`, no `.chip`, no `.panel`, and a bare table is a wall of text with a stylesheet attached. Reach for the class before writing a `div`.
13. **Past two screens, the rail is mandatory.** Not a judgment call and not a reward for hitting 8 items. Any page the reader has to scroll twice gets `nav.toc`, sectioned in document order, each entry showing the ID and a short name. Without it the reader scrolls the whole page just to learn what is on it, which is the single thing the rail exists to prevent.
14. **A rail entry either jumps or swaps.** A plain `a` jumps to a section further down. An `a.tab-link` swaps which `.tab` is shown, for a page holding parallel views of one subject: per package, per environment, per option. Both live in the same rail. Do not build a tab strip above the content, and do not use tabs to hide findings the reader is supposed to triage. With no fragment in the URL every `.tab` stays visible, so the page still reads straight through with scripts off and in print.

## 4. Color

15. **Every hue you assign means one thing, and keeps it page-wide.** `document.css` gives you six, each already named: `--accent` change, `--pos` added or passing, `--neg` removed or failing, `--warn` open, `--note` context, `--move` renamed. Six hues for six kinds of item is fine. Six because the page felt flat is not. Two colors that mean nothing different are a bug.

    This covers the colors the document assigns: chips, rails, panels, tree rows, charts. Syntax highlighting inside a snippet is outside it. Those colors belong to the language, the reader reads them as such, and a code block is quoted material rather than a signal you are sending.
16. **Name the binding where the reader first meets it.** A `.legend`, a chip, or a sentence. An unexplained color is decoration.
17. **Signal a thing once.** An item that already carries a colored chip does not also need a colored edge, a colored heading, and a tinted fill. Pick the one that reads at a glance and delete the rest. Stacked signals are how a flat design turns loud, and they are the most common way a page built from these components goes wrong.
18. **Both themes AA or better.** Check dark before delivering. No low-contrast gray on a colored panel.
19. **No gradient, glassmorphism, glow, or neon.** Flat surfaces: one page background, one panel background, one sunken surface for code, one 1px rule.
20. **No `border-radius`, anywhere, on any element.** There is no radius token to reach for. One type scale, and never size a heading by eye.
21. **Surfaces separate by fill, by hairline, and by space. Never by an outline.** A closed 1px box around a rectangle is the card look, and a page of cards has no hierarchy. A hairline is still fine: the rule under an `h2`, table row separators, tree indent guides, and the 1px gaps in `.counts` and `.list` all stay. What goes is the frame. To mark an edge, use `box-shadow: inset 2px 0 var(--h)`.

## 5. Document design

Applies to plan, review, status, explainer, and comparison. Not to a mockup.

22. **No em-dash anywhere.** Not in headings, body, tables, code, or the title. Not `&mdash;`. Comma, colon, full stop, or rewrite the sentence. Loudest sign a machine wrote the page.
23. **Short sentences, one idea each.** Simplified Technical English. No metaphor. Watch for the trailing clause that starts with *so*, *which*, or *meaning* and then carries the real point: split it into its own sentence. "The budget comes from RetryConfig, read once at startup, so no call site carries its own numbers" is three ideas and a metaphor. "`RetryConfig` holds the retry budget. The program reads it once, at startup. No call site sets its own values" is the same content the reader can check.
24. **Not a landing page.** No hero, call to action, feature grid, pricing block, or emoji. Not "seamless", "powerful", "unleash", "effortless", "game-changing".
25. **Never invent a metric, score, percentage, progress bar, or badge the work did not produce.** A made-up 87% is worse than no number.
26. **Charcoal on off-white, not black on white.** System stack, 16px to 18px, line height 1.6 or more. Not Inter, Roboto, or Open Sans by default.
27. **Every path, symbol, flag, and command in `code`.** `requireSession()`, `src/auth/session.ts:41`, `--dry-run`. The reader scans a technical page for exactly these.
28. **Metadata is not prose.** `.meta` for a standfirst line, `.where` for a `path:line`, `th` for a column head.
29. **Never set text in uppercase.** Not a table head, not a legend, not a standfirst, not a micro-label. A label is small and quiet, not shouted. Tracked out capitals are the second loudest sign a machine wrote the page.
30. **A chip is square.** `.chip` fixes `width` and `height` at 1.9rem. Width from a grid column plus height from padding is never square, and it reads as an accident.
31. **Alternate density on purpose.** Tables and indexes go dense: small type, tight rows, hairline rules. Prose breathes. Table density applied to paragraphs is what makes a page a wall.
32. **Hairlines come from `gap: 1px` over a background color**, which is what `.counts` and `.list` do. Never a border on every child.
33. **`.panel` marks a unit the reader accepts or rejects.** Not every paragraph. A page of cards has no hierarchy, and a panel never nests in a panel. Many small items go in `.list` instead.
34. **Table for repeated fields, prose for everything else.** A one-column table is a list. Every table sits in `.tablewrap`.
35. **One large numeral only when it answers a question the reader already has.** That is what `.counts` is for. Never enlarge a number for rhythm.
36. **Specific element before `div`.** `<del>` and `<ins>` for diff lines, `<samp>` for output, `<kbd>` for keys, `<code>` for source and paths, `<dl>` for label and value pairs, `<time>` for dates, `<article>` for an item the reader acts on, `<nav>` for the contents list.
37. **Style `:target`.** The item the reader jumped to must be marked when they land on it.
38. **Heading levels in order.** Never skip a level to get a size.
39. **Everything visible by default.** No collapsible unless the user asked for a shorter page. `.tabs` is the one exception, and only because it opens showing every panel: the reader hides things by choosing, never by arriving. A full-width `<hr>` separates real units of work, never decorates.
40. **Prefer no motion.** If it earns a place: `transform` and `opacity` only, under 200ms, `prefers-reduced-motion` respected.
41. **No fake screenshot built from `div` elements, and no hand-rolled SVG path data.** A file tree is not a screenshot: use `.tree`, never box drawing characters in a `pre`.

Belongs to poster work, costs legibility here: scanlines, halftone, dithering, noise
overlays, ASCII framing, `>>>` and `///` dividers, invented technical strings, oversized
display type, and deliberate layout variety between sections. A landing page varies its
sections to hold attention. A document repeats one structure so the reader learns it
once and stops looking.

## 6. Content fidelity

42. **Quote the source exactly.** Never paraphrase a line and present it as a quotation.
43. **Cite `path:line`, and name the real symbol.** Not "the auth middleware" but `requireSession()` at `src/auth/session.ts:41`. A page of category nouns cannot be checked.
44. **Give the complete content.** No "and so on", no "for brevity", no `// ...` standing in for the material.

    In a `.tree`, untouched siblings are not the material. The material of a change tree is the changed files. Account for the rest with a counted `.row.rest` line, which is a fact rather than an ellipsis.
45. **State what is not done, not verified, or not applied**, in the page, not only in the chat message. On a page carrying both faults and fixes, every fault says whether it is still true, next to the fault rather than inferable from a fix further down. "is broken" and "was broken" are different claims, and the reader acts on the difference.
46. **Show a proposed file change as a diff**, never as a block of new text that leaves the reader to work out what it replaced. Use `figure.snippet.is-diff` from `reference/snippets.md`. Head it with the path, the line range, and whether it adds, replaces, or deletes. Quote removed lines exactly from the current file. If you have not read that file, say so instead of reconstructing it. Include one or two unchanged lines when they locate the edit.
47. **Show which files a change touches as a `.tree`**, once the count passes three. Statuses, ordering, placement, and what to leave out are in `reference/tree.md`. A tree answers the blast radius question that prose about "the auth layer" cannot, so a page carrying one tree puts it near the top rather than at the end.

48. **Name the thing, do not point at it.** Every paragraph names its own subject, with the `path:line`, even when the heading, the chip, or the `.where` line above already said it. Those are labels, not sentences, and a reader who arrived on an anchor or scanned in from the rail has not read them. "It says the file is inlined" fails. "A comment at `reference/code.js:1-5` still tells the reader to inline the file" works. The same rule kills the vague placement and the paraphrase: write "between `nix` and `bash`", not "beside `nix`", and quote the words you are objecting to, `left as written`, rather than restating them in your own.

49. **A cross reference says what is at the other end.** "which S3 ends" reads only for somebody who has already read S3. Write what the other item does and why it is here: "for `is-diff`, see the change I propose in S3". Mark an aside as an aside, for the same reason: the reader decides what to skip, and only if you tell them they can.

50. **Say what you checked, in your own voice.** "I loaded both grammars in a probe page and checked they render", not "Both grammars load and render". The second states how the world is, which a reader cannot tell apart from an assumption. The first reports work you did, and the work is what they are deciding on. Rule 45 covers what you did not do; this covers what you did.

## 7. Per-shape notes

**plan.** Proposals in execution order. Each carries what changes, why, and what it costs.
Mark what you are not proposing and why, so the reader knows the space was covered.
Open with the decision the reader owes you.

**review.** Findings worst first, severity bound to a hue per rule 15. Each finding: the
location as `path:line`, what breaks, and the concrete failure. Separate "must fix" from
"worth considering" visibly. If you fixed any of them, mark each finding fixed or still
live where it stands, and say so in the section standfirst too. Say what you did not
review.

**status.** Narrative, not a queue. Where the branch is, what landed, what is in flight,
what blocks. End with next actions as a short ordered list, each one a thing the reader
can start today. No IDs, no index, no counts strip. If the honest answer is three
sentences, say so in the terminal and skip the page.

**explainer.** Follow the system's own structure. Lead with the shape of the thing, a
diagram or a table, then the parts. Name every real identifier as `code` so the reader
can grep. No task language, no recommendations, unless asked.

**comparison.** One wide table with options as columns and criteria as rows, the criteria
ordered by how much they matter. Fill every cell. Then a short recommendation naming
which criterion decided it.

**mockup.** A sketch, not a spec and not the implementation. Sections 1, 3 (the
`color-scheme` line), and the delivery rules bind. Sections 4, 5, and 6 do not: gradients,
display type, a hero, marketing voice, motion, several accents, and a single theme are
all available if the design calls for them. State the variation's name and what it tries
in an HTML comment at the top, never rendered. Use the product's real copy where it
exists; invented copy is fine if plausible, `lorem ipsum` is not. Iterate at one slug so
revisions are the history; give simultaneous variations their own slugs
(`myproject-home-v1`, `myproject-home-v2`). Follow the `web-design` skill where it helps.
When a direction wins, write the product code fresh in the repository under its rules.
Do not paste the mockup in as the implementation.

## 8. Reference files

Do not reinvent their contents per document.

- **Always:** `reference/document.css`, uploaded verbatim beside `index.html` and linked. Tokens, layout, and every component in section 3, including `.tree`.
- **Code blocks, diffs, terminals:** `reference/snippets.md` for the markup. Upload `reference/code.css` and `reference/code.js` verbatim beside the page. `code.css` reads the tokens from `document.css`, so link it second. A page with a diff needs them too, which costs nothing now that they are separate files.
- **File trees:** `reference/tree.md` for the markup and the rules. The CSS is already in `document.css`.
- **Icons:** `reference/icons.md`, and `reference/icons.svg` for the file type symbols. Copy only the symbols the page uses.
- **Charts, inline scripts, pinned imports:** `reference/interactive.md`.

`plan_push` takes several files, not one. Pass `files` with `index.html` plus its assets,
each at a relative path, and reference them from the page as siblings. Upload
`document.css`, `code.css`, `code.js` and any image rather than pasting them into the
HTML. They are part of the revision, so they are pinned by construction and an old
revision keeps rendering the way it did.

Three things stay inline anyway:

- **The icon sprite.** `use href="sprite.svg#id"` does not resolve across files in Chrome
  or Safari. Copy the `symbol` elements the page uses into a hidden `svg` in the body.
- **Page specific CSS.** A handful of rules for this document belongs in a `style` block
  after the linked stylesheets, not in a fourth file.
- **A small inline script.** Sorting a table or filtering a list is not worth a file.

No web font, and no stylesheet or script from a host other than plan.env.md. The only
permitted external requests are exactly pinned `https://esm.sh/` imports as described in
`snippets.md` and `interactive.md`. Revisions are permanent, so an unpinned import is a
bug: it changes how an old revision renders later.

## Before you deliver

- [ ] Shape named, and the spine matches it
- [ ] `reference/document.css` uploaded verbatim and linked, and the page uses its classes rather than new ones
- [ ] Past two screens: `nav.toc` present in `.page`, sticky, sectioned in document order
- [ ] Every `.tab-link` points at a `.tab` that exists, and the page still reads with no fragment set
- [ ] Items carry a `.chip`, an `id`, and a visible `:target` state
- [ ] No em-dash anywhere in the file
- [ ] No paragraph opens with `It`, `This` or `They` standing in for a subject named only in a heading or a `.where` line
- [ ] `color-scheme: light dark` present; both themes checked and readable
- [ ] Every hue you assigned means one thing, and the meaning is named
- [ ] Nothing signalled twice: no colored edge on an item that already has a colored chip
- [ ] No `border-radius` in the file, and no closed outline around any surface
- [ ] No uppercase text anywhere
- [ ] Full width: no `max-width`, no centered column, no gutters; every element shares one left and right edge; body scrolls one direction at every width
- [ ] Machinery matches the size: no index, IDs, or counts strip below their thresholds
- [ ] Every file claim cites `path:line`; file changes are diffs with exact removed lines
- [ ] Any tree: folders above files, one `.row` class per status, a `.legend` naming them, a counted `.row.rest` for the siblings not shown
- [ ] Any change tree carries the gutter, and every `.say` gives a real reason rather than "updated"
- [ ] Every `use href` resolves to a `symbol` inlined in this page, never to another file
- [ ] Every snippet declares its language once, in `data-lang` on the figure
- [ ] Nothing truncated, hidden, or placeholdered; what was not done is stated in the page
- [ ] No emoji, no marketing voice, no invented metric
- [ ] Stylesheets and scripts uploaded as siblings and linked; external requests are pinned esm.sh imports only
- [ ] `questions` passed for every decision the reader owes you, each anchored to an `id`
- [ ] Any marker is a `span` carrying only `data-planenv-q`, around a phrase rather than a sentence
- [ ] No browser, no local server, and no screenshot was used to check this page
- [ ] The user has the plan.env.md URL

Mockups check only: pinned imports, `color-scheme`, project-prefixed slug, intent comment
at the top, user has the URL.
