---
name: html-communication
description: Produce a readable HTML document for a human to open outside the terminal on `plan.env.md`. Use for a plan, spec, write-up, findings, summary, report, review, or comparison. Do not use for product UI or design mockups.
---

# HTML Communication

Communication with the user can involve an HTML document. Write one self-contained file, then upload it to plan.env.md and give the user the URL from the response.

## Scope

- This skill is for documents about work. It is not for the product being built.
- Do not apply it to product UI, design mockups, or shipped pages. Those follow repository-local design rules and the `web-design` skill.
- Prefer terminal output for a short answer. Produce a document when the content is long, structured, or read more than one time.

## Upload to plan.env.md

After you write the file, upload it:

```
curl -sS -X PUT "https://plan.env.md/api/docs/<slug>" \
  -H "Authorization: Bearer $(cat ~/.config/plan-env-md/config)" \
  -H "Content-Type: text/html" \
  --data-binary @<file>
```

- Choose the slug from the document's subject: `[a-z0-9-]{1,64}`.
- Prefix the slug with the project: `myproject-auth-refactor`, not
  `auth-refactor`. Slugs share one namespace across all your documents.
- Stay under 512KB; larger uploads are rejected with a 413. An embedded
  image as a data URI is the usual cause.
- Use the config file only through the substitution shown above. Do not
  read, print, or open it; it is on the secrets policy's allowlist for
  exactly this use.
- Reuse the same slug when you update the document. Each upload adds a
  revision at the same URL.
- Give the user the `url` from the response next to the local file path.
- The document is private until the user publishes it in the web UI. Do not
  try to publish it.

## Read a Plan Link

When the user links a plan such as `https://plan.env.md/<id>/<slug>`, take
the slug from the last path segment and read the raw HTML directly:

```
curl -sS "https://plan.env.md/api/docs/<slug>/raw" \
  -H "Authorization: Bearer $(cat ~/.config/plan-env-md/config)"
```

- A link ending in `/rev/<n>`, or a question about an earlier state of the
  plan, reads a pinned revision instead:

```
curl -sS "https://plan.env.md/api/docs/<slug>/revisions/<n>/raw" \
  -H "Authorization: Bearer $(cat ~/.config/plan-env-md/config)"
```

- The revision index (numbers, sizes, dates) is at
  `https://plan.env.md/api/docs/<slug>`.

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
- **One accent color** for interaction and structure, plus at most one semantic pair where the difference carries meaning. Diff additions and removals are that pair. Do not add a third pair.
- **One radius system.** Choose one corner radius and use it for every panel, chip, code block, and table. Do not mix sharp and round.
- **One type scale.** Choose the sizes one time and reuse them. Do not size a heading by eye.
- **Light and dark.** Define both with `prefers-color-scheme`. Do not ship a page that is unreadable in one of them.
- **One file.** No external stylesheet, script, font, or image. Inline the CSS. Embed an image as a data URI or leave it out.

## Typography

- Set the body text between 16px and 18px with a line height of at least 1.6.
- Hold the reading measure near 80 characters. Never exceed 90. Below 65 the page feels cramped and the side margins start to dominate, which readers notice and dislike.
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

- Add a contents list when the document is longer than two screens. Link each entry.
- When a document holds many items, open with an index that names every item, its kind, and its size. The reader must be able to answer "what is all this and where do I start" without scrolling through the detail.
- Classify every item by what the reader must do with it, not by which file it touches. An error to fix, a contradiction to resolve, a proposal to accept or reject, and an observation needing no action are four different jobs, and the reader cannot triage until they are told which is which.
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

## Content Fidelity

- Quote the source exactly. Do not paraphrase a line and present it as a quotation.
- Cite `path:line` for every claim about a file.
- Give the complete content. Do not write "and so on", "for brevity", or `// ...` in place of the material.
- State what is not done, not verified, or not applied. Put it in the document, not only in the chat message.

## Motion and Images

- Prefer no motion. A document does not need a scroll animation.
- If motion earns its place, animate `transform` and `opacity` only, keep it under 200ms, and respect `prefers-reduced-motion`.
- Do not hand-roll an SVG icon. Do not add an icon library. A well-set heading does the work.
- Do not draw a fake screenshot with `div` elements.

## Not For Documents

These belong to landing-page and poster work. They cost legibility here.

- Scanlines, halftone, dithering, and noise overlays.
- ASCII framing, directional syntax such as `>>>` or `///`, and invented technical strings such as unit numbers.
- Zero border-radius as an aesthetic commitment. Square corners are a style choice, not a readability rule.
- Oversized display type. A document heading is a signpost, not a statement.
- Deliberate layout variety between sections. A landing page varies its sections to hold attention. A document repeats one structure so the reader learns it once and stops having to look.

## Before You Deliver

- [ ] No em-dash anywhere in the file
- [ ] One accent color, at most one semantic pair, one radius, one type scale
- [ ] Light and dark both defined and both readable
- [ ] Single file, no external request
- [ ] Reading measure near 80 characters, never above 90
- [ ] Chips are square, with equal width and height
- [ ] Every item has an `id`, and `:target` is styled
- [ ] An index names every item, its kind, and its size
- [ ] Tables and wide code blocks scroll inside their own container
- [ ] The body scrolls in one direction only, at narrow width as well
- [ ] Proposed file changes are shown as diffs with exact removed lines
- [ ] Every file claim cites `path:line`
- [ ] No emoji, no marketing voice, no invented metric
- [ ] Nothing truncated, hidden, or replaced with a placeholder
- [ ] The user has the plan.env.md URL
