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
| under ~6 items, under 2 screens | headings and prose only. No IDs, no index, no contents list |
| 6 or more items | a short ID per item, used as the anchor `id` and in every cross-reference |
| 8 or more items | contents list, sticky sidebar on wide screens, sections in document order |
| 12 or more items | an index table at the top: ID, kind, one line each |
| counts answer the reader's first question | a counts strip, one number per kind, the kind that demands attention first |

3. **IDs are free-form and derived from the page.** One letter per kind plus a number. A plan might use `P1` proposal, `D2` decision, `N3` no action. A review might use `F1` finding, `R2` regression. Name each kind where it first appears. Do not force a page into a vocabulary it does not have, and do not invent a kind to fill a column.
4. **Keep an ID stable across revisions** so the user can say "reject P4" in chat.
5. **Classify an item by what the reader must do with it**, not by which file it touches. An error to fix, a contradiction to resolve, and an observation needing no action are three different jobs, and the reader cannot triage until told which is which. An explainer has no jobs, so it has no kinds. Do not manufacture them.
6. **Order for reading.** Execution order when the work is sequenced, worst-first when the reader triages, the system's own structure for an explainer. Group by kind only when the reader faces an unordered pile.
7. **Link items that depend on each other.** If one requires another, say so and link it.

## 3. Base stylesheet

Start from this. `color-scheme` is not optional: without it the page ships light
scrollbars, light form controls, and a light `light-dark()` fallback on a dark page.

```css
:root {
  color-scheme: light dark;
  --bg: light-dark(#fbfaf8, #14151a);
  --panel: light-dark(#ffffff, #1b1d24);
  --code-bg: light-dark(#f4f3f0, #1f2129);
  --rule: light-dark(#e3e1dc, #2c2f38);
  --ink: light-dark(#1f2024, #e6e6e4);
  --ink-soft: light-dark(#5a5c63, #a2a5ad);
  --ink-faint: light-dark(#8b8d94, #71747d);
  --accent: light-dark(#2f5fd0, #86a8f7);
  --accent-soft: light-dark(#2f5fd014, #86a8f722);
  --pos: light-dark(#1f7a45, #5fbf87);
  --pos-soft: light-dark(#1f7a4514, #5fbf8722);
  --neg: light-dark(#b3261e, #f2867d);
  --neg-soft: light-dark(#b3261e14, #f2867d22);
  --radius: 6px;
  --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
  --measure: 78ch;
  --wide: 1400px;
}
```

Three column widths, one grid. Body content sits in the prose column; anything wide
opts out by class, up to the full viewport.

```css
body {
  display: grid;
  grid-template-columns:
    [full-start] minmax(1rem, 1fr)
    [wide-start] minmax(0, calc((var(--wide) - var(--measure)) / 2))
    [text-start] min(var(--measure), 100%) [text-end]
    minmax(0, calc((var(--wide) - var(--measure)) / 2)) [wide-end]
    minmax(1rem, 1fr) [full-end];
}
body > * { grid-column: text; }
.wide { grid-column: wide; }
.full { grid-column: full; }
```

8. **Prose stays between 70 and 100 characters.** Below 70 the margins dominate and readers dislike it. Above 100 the eye loses the line start.
9. **Everything else is free to be wide.** A comparison table, an architecture diagram, a dense reference grid, a wide diff, and a dashboard-style overview all belong in `.wide` or `.full`. The measure constrains paragraphs, not the page.
10. **A full-width page is correct when the content is not prose.** An explainer that is mostly diagram, or a comparison that is one large table, may drop the prose column entirely.
11. **Every table, wide code block, and diagram scrolls inside its own `overflow-x: auto` container.** The body scrolls one direction only, at narrow width too.

## 4. Color

12. **Every hue binds to one stated meaning, and that meaning keeps that hue everywhere on the page.** Severity levels, categories in an overview, services in an architecture map, and series in a chart are all legitimate reasons to carry five hues. Two colors that mean nothing different are a bug.
13. **Name the binding where the reader first meets it.** A legend, a chip, or a sentence. An unexplained color is decoration.
14. **Both themes readable, AA or better.** Check the dark side before delivering. Do not put low-contrast gray on a colored panel.
15. **No gradient, glassmorphism, glow, or neon in a document.** They separate nothing and cost legibility. Flat surfaces: one page background, one panel background, one 1px rule.
16. **One radius, one type scale.** Pick the corner radius once and use it on every panel, chip, code block, and table. Pick the sizes once. Do not size a heading by eye.

## 5. Document design

Applies to plan, review, status, explainer, and comparison. Not to a mockup.

17. **No em-dash anywhere.** Not in headings, body, tables, code, or the title. Not `&mdash;`. Use a comma, a colon, a full stop, or a rewritten sentence. This is the loudest sign a machine wrote the page.
18. **Not a landing page.** No hero, no call to action, no feature grid, no pricing block, no marketing voice, no emoji. Do not write "seamless", "powerful", "unleash", "effortless", "game-changing".
19. **Never invent a metric, score, percentage, progress bar, or status badge the work did not produce.** A confidence number you made up is worse than no number.
20. **Charcoal on off-white, not black on white.** System font stack for body, 16px to 18px, line height 1.6 or more. If you pick a specific face, pick it for a reason. Not Inter, Roboto, or Open Sans by default.
21. **Set every path, symbol, flag, and command in `code`.** The reader scans a technical page for exactly these.
22. **Metadata is not prose.** Labels, table headers, chips, and counters go in the monospace face, uppercase, 10px to 14px, letter-spacing 0.05em to 0.1em. Ration them: more than one uppercase micro-label per screen and none of them signal anything.
23. **Size a chip with equal `width` and `height`.** A chip whose width comes from a grid column and whose height comes from padding is never square and reads as an accident.
24. **Alternate density on purpose.** A reference table, an index, or a status list is dense: small type, tight rows, hairline rules. Prose breathes. Applying table density to paragraphs is what makes a page a wall.
25. **Draw hairlines with `display: grid; gap: 1px` over a background color**, not a border on every child.
26. **Use a panel for a discrete unit the reader acts on**, such as one proposal to accept. Do not panel every paragraph. A page of cards has no hierarchy. Do not nest a panel in a panel.
27. **Use a table when the content has repeated fields, prose when it does not.** A one-column table is a list.
28. **One large numeral only where it answers a question the reader already has.** Do not enlarge a number for rhythm.
29. **Reach for the specific element before a `div`.** `<del>` and `<ins>` for diff lines, `<samp>` for program output, `<kbd>` for keys, `<code>` for source and paths, `<dl>` for label and value pairs, `<time>` for dates, `<article>` for a self-contained item the reader acts on, `<nav>` for the contents list.
30. **Style `:target`** so an item the reader jumped to is marked when they arrive.
31. **Heading levels in order.** Do not skip a level to get a different size.
32. **Everything visible by default.** No collapsible unless the user asked for a shorter page. A full-width `<hr>` separates real units of work, never decorates.
33. **Prefer no motion.** If it earns its place: `transform` and `opacity` only, under 200ms, respect `prefers-reduced-motion`.
34. **Do not draw a fake screenshot out of `div` elements**, and do not hand-roll SVG path data.

Belongs to poster work, costs legibility here: scanlines, halftone, dithering, noise
overlays, ASCII framing, `>>>` and `///` dividers, invented technical strings, oversized
display type, and deliberate layout variety between sections. A landing page varies its
sections to hold attention. A document repeats one structure so the reader learns it
once and stops looking.

## 6. Content fidelity

35. **Quote the source exactly.** Do not paraphrase a line and present it as a quotation.
36. **Cite `path:line` for every claim about a file.**
37. **Give the complete content.** No "and so on", no "for brevity", no `// ...` standing in for the material.
38. **State what is not done, not verified, or not applied**, in the page, not only in the chat message.
39. **Show a proposed file change as a diff**, never as a block of new text that leaves the reader to work out what it replaced. Head it with the path, the line range, and whether it adds, replaces, or deletes. Quote removed lines exactly from the current file. If you have not read that file, say so instead of reconstructing it. Include one or two unchanged lines when they locate the edit.

## 7. Per-shape notes

**plan.** Proposals in execution order. Each carries what changes, why, and what it costs.
Mark what you are not proposing and why, so the reader knows the space was covered.
Open with the decision the reader owes you.

**review.** Findings worst first, severity bound to a hue per rule 12. Each finding: the
location as `path:line`, what breaks, and the concrete failure. Separate "must fix" from
"worth considering" visibly. Say what you did not review.

**status.** Narrative, not a queue. Where the branch is, what landed, what is in flight,
what blocks. End with next actions as a short ordered list, each one a thing the reader
can start today. No IDs, no index, no counts strip. If the honest answer is three
sentences, say so in the terminal and skip the page.

**explainer.** Follow the system's own structure. Lead with the shape of the thing, a
diagram or a wide table, then the parts. Name every real identifier as `code` so the
reader can grep. No task language, no recommendations, unless asked. Full-width is
usually right here.

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

Read these when the page needs them. Do not reinvent their contents per document.

- **Code blocks, diffs, terminals, tabbed alternatives:** `reference/snippets.md`, which inlines `reference/code.css` and `reference/code.js` verbatim.
- **Charts, icons, inline scripts, pinned imports:** `reference/interactive.md`.

One file, no external stylesheet, no web font. Inline the CSS, embed images as data URIs
or leave them out. The only permitted external requests are exactly pinned `https://esm.sh/`
imports as described in those two files. Revisions are permanent, so an unpinned import
is a bug: it changes how an old revision renders later.

## Before you deliver

- [ ] Shape named, and the spine matches it
- [ ] No em-dash anywhere in the file
- [ ] `color-scheme: light dark` present; both themes checked and readable
- [ ] Every hue means one thing, and the meaning is named
- [ ] Prose 70 to 100 characters; wide content in `.wide` or `.full`; body scrolls one direction at every width
- [ ] Machinery matches the size: no index, IDs, or counts strip below their thresholds
- [ ] Every file claim cites `path:line`; file changes are diffs with exact removed lines
- [ ] Nothing truncated, hidden, or placeholdered; what was not done is stated in the page
- [ ] No emoji, no marketing voice, no invented metric
- [ ] Single file; external requests are pinned esm.sh imports only
- [ ] The user has the plan.env.md URL

Mockups check only: single file, pinned imports, `color-scheme`, project-prefixed slug,
intent comment at the top, user has the URL.
