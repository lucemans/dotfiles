---
name: plan-env
description: Produce a self-contained HTML page for a human to open on `plan.env.md`. Use for a plan, spec, write-up, findings, summary, report, review, comparison, mockup, or design sketch.
---

# Plan Env

Communication with the user can involve an HTML page: a document about work, or a mockup exploring a design. Use the available plan-env MCP tools to upload and read it.

## Scope

- This skill covers two kinds of page, delivered the same way.
- A document communicates about work: a plan, spec, write-up, findings, summary, report, review, or comparison. Every section of this skill applies to it.
- A mockup explores product UI: a design variation, a page or component sketch, a brainstorm made to be looked at. The Mockups section says which rules bind it; the document design rules do not.
- Neither kind is shipped code. Product code in a repository follows the repository's design rules and the `web-design` skill.
- Prefer terminal output for a short answer. Produce a page when the content is long, structured, visual, or read more than one time.

## Upload to plan.env.md

Use `plan_env_plan_push` to upload complete self-contained HTML. Choose a
project-prefixed subject slug: `[a-z0-9-]{1,64}`, such as
`myproject-auth-refactor`, not `auth-refactor`. Slugs share one namespace.
Keep the HTML under 512 KB. Reuse the slug to add a revision. Give the user the
returned URL. Do not try to publish the document.

## Read a Plan Link

Use `plan_env_plan_read` for a document URL or slug, for example
`https://plan.env.md/<id>/<slug>`. A revision URL ends with `/rev/<n>`, for
example `https://plan.env.md/<id>/<slug>/rev/2`; pass it to
`plan_env_plan_read` to read that pinned revision. Use `plan_env_plan_info` for
the document metadata and revision index.

## Mockups

A mockup is a sketch, not a specification and not the implementation. Optimize for how fast the idea becomes visible.

- The delivery rules still bind: one self-contained file, inline CSS, external requests only as pinned esm.sh imports, under 512KB, a project-prefixed slug, the URL given to the user.
- The document design rules do not bind. A mockup may use gradients, display type, a hero, marketing voice, motion, several accents, or a single theme: whatever the design it explores calls for. The list in Not For Documents is available here.
- Follow the `web-design` skill's conventions where they help. Break them deliberately when the exploration is about breaking them.
- State the intent in an HTML comment at the top of the file: the variation's name and one line on what it tries. Do not render this into the design.
- Iterate at one slug; the revisions are the history of the exploration. Simultaneous variations get their own slugs, `myproject-home-v1`, `myproject-home-v2`, so each can be revised independently.
- Use the product's real copy when it exists. Invented copy and data are fine in a sketch; keep them plausible rather than `lorem ipsum`, so the design is judged with honest content.
- When a direction wins, write the product code fresh in the repository under its rules. Do not paste the mockup in as the implementation.

## Before You Write

State the reader's job in one sentence, to yourself, before you write any markup. "Decide which of these twenty proposals to accept." "Understand why the build broke." Every layout decision then serves that job.

If the reader's job is to choose, the document must make the choices countable and comparable on the first screen. A document that buries the decision under its own reasoning has failed, however well written the reasoning is.

## A Document Is Not a Landing Page

- Do not write a hero, a call to action, a feature grid, or a pricing block.
- Do not write marketing voice. Do not use words such as "seamless", "powerful", "unleash", "effortless", or "game-changing".
- Do not use emoji.
- Do not invent a metric, a score, a progress bar, or a status badge that the work did not produce.
- The reader wants the content. The design serves the reading, not the impression.

## Hard Rules

- **No em-dash.** Do not use an em-dash or `&mdash;` anywhere: headings, body, tables, code, or the title. Use a comma, a colon, a full stop, or a rewritten sentence. This is the clearest sign that a machine wrote the page.
- **One accent color** for interaction and structure, plus at most one semantic pair where the difference carries meaning. Diff additions and removals are that pair. Do not add a third pair. Syntax token colors inside a code snippet come from the pinned Shiki themes in Code Snippets and sit outside this rule.
- **One radius system.** Choose one corner radius and use it for every panel, chip, code block, and table. Do not mix sharp and round.
- **One type scale.** Choose the sizes one time and reuse them. Do not size a heading by eye.
- **Light and dark.** Define both with `prefers-color-scheme`. Do not ship a page that is unreadable in one of them.
- **One file, pinned imports.** No external stylesheet or font. Inline the CSS. Embed an image as a data URI or leave it out. A document with interactive data or highlighted code may import scripts from `https://esm.sh/` with exact pinned versions; the rules are in Interactive Content and Code Snippets.

## Typography

- Set the body text between 16px and 18px with a line height of at least 1.6.
- Hold the prose measure between 85 and 100 characters. Never exceed 110. Below 70 the page feels cramped and the side margins start to dominate, which readers notice and dislike.
- The measure constrains paragraphs, not the page. Give tables, charts, code blocks, and diffs a wider breakout column: center the prose column and let wide elements span `width: min(1100px, 100%)` of the viewport, each scrolling inside its own container when narrower than its content.
- Use charcoal on off-white. Do not use pure black on pure white.
- Use a system font stack for body text. If you choose a specific face, choose it with purpose. Do not choose Inter, Roboto, or Open Sans by default.
- Use one monospace face for code, paths, identifiers, and commands.
- Set every file path, symbol, flag, and command in `code`. The reader scans a technical document for these.

## Micro-Typography

Metadata is not prose and should not look like prose.

- Set labels, table headers, chips, and counters in the monospace face, uppercase, between 10px and 14px, with letter-spacing between 0.05em and 0.1em.
- Ration them. No more than one uppercase micro-label per screen of content. If every block has one, none of them read as a signal.
- Size a chip by setting equal `width` and `height`. A chip whose width comes from a grid column and whose height comes from padding is never square, and it looks like an accident.

## Color and Surface

- Use flat surfaces. One page background, one panel background, one 1px border color.
- Do not use a gradient, glassmorphism, a heavy shadow, a glow, or a neon color.
- Use color to carry meaning only. If two elements have different colors, the difference must mean something.
- Keep text contrast at WCAG AA or better in both themes. Do not put low-contrast gray on a colored panel.

## Density and Texture

Alternate density on purpose. This is the one thing that stops a document reading as an undifferentiated wall.

- A reference table, an index, or a status list should be dense: small type, tight rows, hairline rules.
- Prose should breathe. Do not apply table density to paragraphs.
- Draw hairline dividers with `display: grid; gap: 1px` over a background color, rather than putting a border on every child.
- Use a full-width `<hr>` only to separate genuine units of work, never as decoration.
- Use one large numeral only where it answers a question the reader already has, such as a count of open items. Do not enlarge a number for rhythm.

## Semantic HTML

The tag is part of the meaning. Reach for the specific element before reaching for a `div` and a class.

- `<del>` and `<ins>` for removed and added lines in a diff.
- `<samp>` for program output, `<kbd>` for keys the user presses, `<code>` for source and paths.
- `<dl>` for label and value pairs. `<time>` for dates. `<data>` for a value with a machine-readable form.
- `<article>` for a self-contained item the reader acts on. `<nav>` for the contents list.
- Give every item an `id`, and style `:target` so the item the reader jumped to is visibly marked when they arrive.

## Structure

- Add a contents list when the document is longer than two screens. Link each entry. Past roughly eight items, make it a sidebar: sticky beside the prose on wide screens, sectioned to match the document's own order, each entry showing the item ID and a short name.
- Give every item the reader acts on a short stable ID shown in a chip, one letter per kind plus a number: `D1`, `P2`, `S3`. Derive the letters from the kinds this document actually has, and name each kind where it first appears. A plan might use D for a decision, P for a proposal, N for no action. A review might use S for a strength, R for a regression, F for a finding to fix. A status report might use W for what advanced, B for what is blocked. These are examples, not the list.
- Use the ID as the anchor id and in every cross-reference, and keep it stable across revisions, so the user can name an item in conversation.
- Order and group items the way the document reads best. Group by kind when the reader triages an unordered set. Keep related items together when they explain each other, and use chronological or execution order when the content has one. The chip already names each item's kind, so the grouping is free to serve the reading.
- Open with a counts strip when the totals answer the reader's first question: one number per kind, the kinds that demand attention first.
- When a document holds many items, open with an index that names every item, its kind, and its size. The reader must be able to answer "what is all this and where do I start" without scrolling through the detail.
- Classify every item by what the reader must do with it, not by which file it touches. An error to fix, a contradiction to resolve, a proposal to accept or reject, and an observation needing no action are four different jobs, and the reader cannot triage until they are told which is which. The set of jobs follows from the document: a plan carries proposals to accept, a review carries strengths to keep and regressions to fix, a status report carries progress to confirm and blockers to clear.
- Link between items that depend on each other. If one item requires another, say so and link it.
- Use a panel to mark a discrete unit, such as one proposal the reader accepts or rejects. Do not put every paragraph in a panel. A page of cards has no hierarchy.
- Do not nest a panel inside a panel.
- Use a table when the content has repeated fields. Use prose when it does not. Do not build a table with one column.
- Put a table, a wide code block, and a diagram in a container with `overflow-x: auto`. The page body must never scroll sideways.
- Keep the heading levels in order. Do not skip a level to get a different size.
- Do not hide content behind a collapsible unless the reader has asked for a shorter page. Default to everything visible.

## Proposed File Changes

- Show a proposed change to a file as a diff, with removed and added lines marked, not as a block of new text that leaves the reader to work out what it replaces.
- Quote the removed lines exactly from the current file. If you have not read the current file, say so rather than reconstructing it from memory.
- Head each diff with the file path and the line range, and say whether it adds, replaces, or deletes.
- Show one or two unchanged lines around the change when they tell the reader where the edit lands.

## Code Snippets

Every code block longer than one line sits in one snippet layout. Do not write snippet styles or a highlight runtime per document: inline `reference/code.css` into the stylesheet and `reference/code.js` as the last module script, both verbatim. They assume the document defines the standard tokens (`--panel`, `--code-bg`, `--rule`, `--radius`, `--mono`, `--ink-soft`, `--ink-faint`, `--accent`, `--accent-soft`, `--pos`, `--pos-soft`, `--neg`, `--neg-soft`).

- Wrap the block in a `figure` with class `snippet`: a `figcaption` header row, then the `pre`.
- The header names the source. Quoted code gets the file path and line range. New or illustrative code gets a short title. The language tag sits at the right end. The field order never changes.
- Content Fidelity applies inside a snippet: quote exactly, escape exactly, elide nothing.

```
<figure class="snippet">
  <figcaption><code>src/server.ts:12-24</code><span class="lang">typescript</span></figcaption>
  <pre><code class="language-typescript">...</code></pre>
</figure>
```

- Highlighting runs at read time with Shiki, pinned inside `reference/code.js`. Supported languages: `typescript`, `javascript`, `rust`, `nix`, `bash`, `json`, `css`, `solidity`, and `ansi`. Any other language renders plain; do not add grammars per document.
- The page must read fully with scripts disabled. Highlighting decorates text that is already present; never build a snippet whose content arrives by script.

Vary a snippet only through these markers, written as a comment in the language's own comment syntax on the affected line. The runtime strips the marker and applies the effect. With scripts disabled the marker text stays visible, which is acceptable; an invented marker is not.

| Effect | Marker |
| --- | --- |
| Emphasize a line | `// [!code highlight]` |
| Dim everything except the marked lines | `// [!code focus]` |
| Added and removed lines in illustrative code | `// [!code ++]` and `// [!code --]` |
| Emphasize one word | `// [!code word:port]` |
| Mark the failing or suspect line | `// [!code error]`, `// [!code warning]` |

- Line numbers: add class `numbered` to the figure, only when prose refers to line positions.
- Program output with color: `language-ansi`, preserving the raw escape codes.
- A terminal exchange: class `is-terminal` on the figure. Commands are `code` lines inside one `pre` with class `cmds`; output follows as its own `pre` holding `samp` or `language-ansi` content. The `$` prompt comes from CSS and is never part of the text, so copied commands stay runnable.
- Alternatives shown once (package managers, platforms): class `is-group` on the figure, hidden radio inputs first, then the `figcaption` with one `label` per alternative in its `.tabs` span, then one `section` per alternative in the same order. The tabs are CSS-only and work without scripts. Up to four alternatives.
- A proposed change to a real file keeps the diff block from Proposed File Changes. Notation diff is for illustration, not for edits the reader applies.

## Content Fidelity

- Quote the source exactly. Do not paraphrase a line and present it as a quotation.
- Cite `path:line` for every claim about a file.
- Give the complete content. Do not write "and so on", "for brevity", or `// ...` in place of the material.
- State what is not done, not verified, or not applied. Put it in the document, not only in the chat message.

## Interactive Content

The document is served in a sandbox with an opaque origin: scripts run, but
cookies and credentialed requests do not exist. Within that, interactivity is
welcome when it serves the reading, never as decoration.

- Small inline vanilla JavaScript is fine: sorting a table, filtering a list,
  toggling between two views of the same data. No frameworks; Solid and React
  need a build step and do not belong in a document.
- Charts use TanStack Charts through esm.sh with an exact pinned version and
  its framework-free host. The pattern:

```
<div id="chart"><p>Interactive chart. The data is in the table below.</p></div>
<script type="module">
import { defineChart, lineY, barY, mountChart }
  from "https://esm.sh/@tanstack/charts@0.11.2";
import { scaleLinear } from "https://esm.sh/@tanstack/charts@0.11.2/scales/linear";
import { scaleBand } from "https://esm.sh/@tanstack/charts@0.11.2/scales/band";

const element = document.querySelector("#chart");
element.replaceChildren();
mountChart(element, { definition, height: 300, ariaLabel: "..." });
</script>
```

- Pick the chart series color per theme with `matchMedia("(prefers-color-scheme: dark)")`
  and keep it clearly readable against both surfaces; one hue for one series,
  a fixed assignment per series for more, never a rainbow.
- Every chart also ships its data as a table in the document. The page must
  stay fully readable when esm.sh is unreachable or scripts are disabled: the
  chart container keeps fallback text until the mount succeeds.
- Icons are inlined at write time, not loaded at runtime: fetch the SVG from
  `https://unpkg.com/lucide-static@1.31.0/icons/<name>.svg`, paste it inline,
  size it to the text beside it (`width="1em" height="1em"`), and let it
  inherit color through `currentColor`. Use them sparingly: a label beats an
  icon that needs explaining.
- Pin every imported version exactly. Revisions are permanent; an unpinned
  import changes how old revisions render later and is a bug.

## Motion and Images

- Prefer no motion. A document does not need a scroll animation.
- If motion earns its place, animate `transform` and `opacity` only, keep it under 200ms, and respect `prefers-reduced-motion`.
- Do not hand-roll SVG path data and do not load an icon library at runtime. When an icon earns its place, inline one from Lucide as described in Interactive Content; a well-set heading often does the work instead.
- Do not draw a fake screenshot with `div` elements.

## Not For Documents

These belong to landing-page and poster work. They cost legibility here.

- Scanlines, halftone, dithering, and noise overlays.
- ASCII framing, directional syntax such as `>>>` or `///`, and invented technical strings such as unit numbers.
- Zero border-radius as an aesthetic commitment. Square corners are a style choice, not a readability rule.
- Oversized display type. A document heading is a signpost, not a statement.
- Deliberate layout variety between sections. A landing page varies its sections to hold attention. A document repeats one structure so the reader learns it once and stops having to look.

## Before You Deliver

This checklist is for documents. A mockup checks only the delivery rules in Mockups: single file, pinned imports only, project-prefixed slug, intent comment at the top, and the user has the URL.

- [ ] No em-dash anywhere in the file
- [ ] One accent color, at most one semantic pair, one radius, one type scale
- [ ] Light and dark both defined and both readable
- [ ] Single file; the only external requests are pinned esm.sh imports for interactive data and code highlighting
- [ ] Every chart has its data in a table as well, and survives scripts failing to load
- [ ] Prose measure between 85 and 100 characters, never above 110; wide elements break out to their own wider column
- [ ] Chips are square, with equal width and height
- [ ] Every item has an `id`, and `:target` is styled
- [ ] An index names every item, its kind, and its size
- [ ] Tables and wide code blocks scroll inside their own container
- [ ] The body scrolls in one direction only, at narrow width as well
- [ ] Proposed file changes are shown as diffs with exact removed lines
- [ ] Every code snippet sits in the snippet layout with its source named in the header
- [ ] reference/code.css and reference/code.js are inlined verbatim, not paraphrased
- [ ] Snippet variation uses only the notation markers listed in Code Snippets
- [ ] Items carry stable kind-prefixed IDs, with the kinds derived from this document and named where they first appear
- [ ] Past eight items the contents list is a sidebar whose sections match the document's own order
- [ ] Every file claim cites `path:line`
- [ ] No emoji, no marketing voice, no invented metric
- [ ] Nothing truncated, hidden, or replaced with a placeholder
- [ ] The user has the plan.env.md URL
