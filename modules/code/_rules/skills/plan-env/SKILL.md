---
name: plan-env
description: Build a self-contained HTML page and host it on `plan.env.md` for a human to open. Use for a plan, spec, review, status update, findings, explainer, architecture or feature overview, comparison, research write-up, or UI mockup. Also use to read a plan.env.md link the user pastes.
---

# Plan Env

You write one HTML file, push it, and give the user the URL. The page is read by a
human in a browser, not shipped as product code.

**Push.** `plan_env_plan_push` with complete self-contained HTML, under 512 KB, and a
project-prefixed slug matching `[a-z0-9-]{1,64}`: `myproject-auth-refactor`, not
`auth-refactor`. Slugs share one global namespace. Reuse a slug to add a revision.
Give the user the returned URL. Never try to publish beyond this.

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

3. **IDs are free-form and derived from the page.** One letter per kind plus a number. A plan might use `P1` proposal, `D2` decision, `N3` no action. A review might use `F1` finding, `R2` regression. Name each kind where it first appears. Do not force a page into a vocabulary it does not have, and do not invent a kind to fill a column.
4. **Keep an ID stable across revisions** so the user can say "reject P4" in chat.
5. **Classify an item by what the reader must do with it**, not by which file it touches. An error to fix, a contradiction to resolve, and an observation needing no action are three different jobs, and the reader cannot triage until told which is which. An explainer has no jobs, so it has no kinds. Do not manufacture them.
6. **Order for reading.** Execution order when the work is sequenced, worst-first when the reader triages, the system's own structure for an explainer. Group by kind only when the reader faces an unordered pile.
7. **Link items that depend on each other.** If one requires another, say so and link it.

## 3. Stylesheet and components

Inline `reference/document.css` verbatim. It carries the tokens, the full-width
layout, and every component below. Do not retype it, do not trim it, and do not
invent a parallel set of class names. Add page-specific rules after it.

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
| `.tablewrap` > `table` | Any table. The wrapper owns the border and the scroll |
| `td.id`, `td.sz`, `tr:target` | Index table: ID column, size column, jumped-to row |
| `.list` > `article` | Many items, hairline separated, each with an `id` and a `:target` state |
| `.panel` | One discrete unit the reader accepts or rejects. Never nested |
| `.split` | Two things compared side by side inside one panel |
| `.diff` with `<ins>` and `<del>` | A proposed change to a real file |
| `.lede`, `.meta`, `.where`, `.soft`, `.ok`, `.bad` | Standfirst, uppercase metadata, a `path:line`, muted prose, pass, fail |

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
12. **Use the components, or the page comes out flat.** A page with no `nav.toc`, no `.chip`, no `.panel`, and an unbordered table is a wall of text with a stylesheet attached. Reach for the class before writing a `div`.
13. **Past two screens, the rail is mandatory.** Not a judgment call and not a reward for hitting 8 items. Any page the reader has to scroll twice gets `nav.toc`, sectioned in document order, each entry showing the ID and a short name. Without it the reader scrolls the whole page just to learn what is on it, which is the single thing the rail exists to prevent.
14. **A rail entry either jumps or swaps.** A plain `a` jumps to a section further down. An `a.tab-link` swaps which `.tab` is shown, for a page holding parallel views of one subject: per package, per environment, per option. Both live in the same rail. Do not build a tab strip above the content, and do not use tabs to hide findings the reader is supposed to triage. With no fragment in the URL every `.tab` stays visible, so the page still reads straight through with scripts off and in print.

## 4. Color

15. **Every hue means one thing, and keeps it page-wide.** Five hues for five severity levels is fine. Five hues because the page felt flat is not. Two colors that mean nothing different are a bug.
16. **Name the binding where the reader first meets it.** A legend, a chip, or a sentence. An unexplained color is decoration.
17. **Both themes AA or better.** Check dark before delivering. No low-contrast gray on a colored panel.
18. **No gradient, glassmorphism, glow, or neon.** Flat surfaces: one page background, one panel background, one 1px rule.
19. **One radius, one type scale.** Set `--radius` once and use it on every panel, chip, code block, and table. Never size a heading by eye.
20. **Never put a one-sided border on a rounded element.** `border-left: 3px solid var(--accent)` plus `border-radius: 6px` leaves the stripe cut off square against a curved corner, and it looks like a bug because it is one. Mark an edge with an inset shadow instead: `box-shadow: inset 3px 0 var(--accent)`, which follows the radius. That is what `.diff ins`, `.diff del`, and the snippet notation lines already do. A border either runs on all four sides or is not a border.

## 5. Document design

Applies to plan, review, status, explainer, and comparison. Not to a mockup.

21. **No em-dash anywhere.** Not in headings, body, tables, code, or the title. Not `&mdash;`. Comma, colon, full stop, or rewrite the sentence. Loudest sign a machine wrote the page.
22. **Not a landing page.** No hero, call to action, feature grid, pricing block, or emoji. Not "seamless", "powerful", "unleash", "effortless", "game-changing".
23. **Never invent a metric, score, percentage, progress bar, or badge the work did not produce.** A made-up 87% is worse than no number.
24. **Charcoal on off-white, not black on white.** System stack, 16px to 18px, line height 1.6 or more. Not Inter, Roboto, or Open Sans by default.
25. **Every path, symbol, flag, and command in `code`.** `requireSession()`, `src/auth/session.ts:41`, `--dry-run`. The reader scans a technical page for exactly these.
26. **Metadata is not prose.** `.meta` for a standfirst line, `.where` for a `path:line`, `th` for a column head. Ration the uppercase: one micro-label per screen, or none of them signal anything.
27. **A chip is square.** `.chip` fixes `width` and `height` at 1.9rem. Width from a grid column plus height from padding is never square, and it reads as an accident.
28. **Alternate density on purpose.** Tables and indexes go dense: small type, tight rows, hairline rules. Prose breathes. Table density applied to paragraphs is what makes a page a wall.
29. **Hairlines come from `gap: 1px` over a background color**, which is what `.counts` and `.list` do. Never a border on every child.
30. **`.panel` marks a unit the reader accepts or rejects.** Not every paragraph. A page of cards has no hierarchy, and a panel never nests in a panel. Many small items go in `.list` instead.
31. **Table for repeated fields, prose for everything else.** A one-column table is a list. Every table sits in `.tablewrap`.
32. **One large numeral only when it answers a question the reader already has.** That is what `.counts` is for. Never enlarge a number for rhythm.
33. **Specific element before `div`.** `<del>` and `<ins>` for diff lines, `<samp>` for output, `<kbd>` for keys, `<code>` for source and paths, `<dl>` for label and value pairs, `<time>` for dates, `<article>` for an item the reader acts on, `<nav>` for the contents list.
34. **Style `:target`.** The item the reader jumped to must be marked when they land on it.
35. **Heading levels in order.** Never skip a level to get a size.
36. **Everything visible by default.** No collapsible unless the user asked for a shorter page. `.tabs` is the one exception, and only because it opens showing every panel: the reader hides things by choosing, never by arriving. A full-width `<hr>` separates real units of work, never decorates.
37. **Prefer no motion.** If it earns a place: `transform` and `opacity` only, under 200ms, `prefers-reduced-motion` respected.
38. **No fake screenshot built from `div` elements, and no hand-rolled SVG path data.**

Belongs to poster work, costs legibility here: scanlines, halftone, dithering, noise
overlays, ASCII framing, `>>>` and `///` dividers, invented technical strings, oversized
display type, and deliberate layout variety between sections. A landing page varies its
sections to hold attention. A document repeats one structure so the reader learns it
once and stops looking.

## 6. Content fidelity

39. **Quote the source exactly.** Never paraphrase a line and present it as a quotation.
40. **Cite `path:line`, and name the real symbol.** Not "the auth middleware" but `requireSession()` at `src/auth/session.ts:41`. A page of category nouns cannot be checked.
41. **Give the complete content.** No "and so on", no "for brevity", no `// ...` standing in for the material.
42. **State what is not done, not verified, or not applied**, in the page, not only in the chat message.
43. **Show a proposed file change as a diff**, never as a block of new text that leaves the reader to work out what it replaced. Head it with the path, the line range, and whether it adds, replaces, or deletes. Quote removed lines exactly from the current file. If you have not read that file, say so instead of reconstructing it. Include one or two unchanged lines when they locate the edit.

## 7. Per-shape notes

**plan.** Proposals in execution order. Each carries what changes, why, and what it costs.
Mark what you are not proposing and why, so the reader knows the space was covered.
Open with the decision the reader owes you.

**review.** Findings worst first, severity bound to a hue per rule 13. Each finding: the
location as `path:line`, what breaks, and the concrete failure. Separate "must fix" from
"worth considering" visibly. Say what you did not review.

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

- **Always:** `reference/document.css`, inlined verbatim. Tokens, layout, and every component in section 3.
- **Code blocks, diffs, terminals, tabbed alternatives:** `reference/snippets.md`, which inlines `reference/code.css` and `reference/code.js` verbatim. `code.css` reads the tokens from `document.css`, so it goes second.
- **Charts, icons, inline scripts, pinned imports:** `reference/interactive.md`.

One file, no external stylesheet, no web font. Inline the CSS, embed images as data URIs
or leave them out. The only permitted external requests are exactly pinned `https://esm.sh/`
imports as described in those two files. Revisions are permanent, so an unpinned import
is a bug: it changes how an old revision renders later.

## Before you deliver

- [ ] Shape named, and the spine matches it
- [ ] `reference/document.css` inlined verbatim, and the page uses its classes rather than new ones
- [ ] Past two screens: `nav.toc` present in `.page`, sticky, sectioned in document order
- [ ] Every `.tab-link` points at a `.tab` that exists, and the page still reads with no fragment set
- [ ] Items carry a `.chip`, an `id`, and a visible `:target` state
- [ ] No em-dash anywhere in the file
- [ ] `color-scheme: light dark` present; both themes checked and readable
- [ ] Every hue means one thing, and the meaning is named
- [ ] No one-sided border anywhere on a rounded element; edge markers are `box-shadow: inset`
- [ ] Full width: no `max-width`, no centered column, no gutters; every element shares one left and right edge; body scrolls one direction at every width
- [ ] Machinery matches the size: no index, IDs, or counts strip below their thresholds
- [ ] Every file claim cites `path:line`; file changes are diffs with exact removed lines
- [ ] Nothing truncated, hidden, or placeholdered; what was not done is stated in the page
- [ ] No emoji, no marketing voice, no invented metric
- [ ] Single file; external requests are pinned esm.sh imports only
- [ ] The user has the plan.env.md URL

Mockups check only: single file, pinned imports, `color-scheme`, project-prefixed slug,
intent comment at the top, user has the URL.
