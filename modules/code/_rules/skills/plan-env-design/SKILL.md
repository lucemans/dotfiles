---
name: plan-env-design
description: Design a screen as an HTML page and host it on `plan.env.md` for a human to look at. Use for a UI mockup, a screen sketch, a visual direction, or several simultaneous design variations of one screen. For a plan, spec, review, status, findings, explainer, comparison or research write-up, use `plan-env` instead.
---

# Plan Env Design

You write one HTML page that shows a screen, push it, and give the user the URL. The
reader opens it, looks at it, and reacts. This skill owns the mockup. Anything the reader
reads rather than looks at belongs to `plan-env`.

**Push.** The tool is the same one, so here it is once. `plan_env_plan_push` with `files`:
`index.html` plus its assets, each at a relative path, under 512 KB. Call
`plan_env_plan_projects` first and pass `project`. Use a project-prefixed slug matching
`[a-z0-9-]{1,64}`, `myproject-home-v1` and never `home-v1`, because slugs share one
global namespace. Build the files under `.tmp/docs/<slug>/` and push them from there.
Give the user the returned URL.

**Never open the page yourself.** No local web server, no headless browser, no
screenshot. A push that returns a URL succeeded, and that is the whole check.
`plan_env_plan_read` reads back what you sent if you need it.

## `reference/document.css` does not apply

Do not upload it, and do not link it. Its class names name the parts of a document
somebody reads: `nav.toc`, `.panel`, `.chip`, `.counts`, `.list`, `.tablewrap`. A screen
has a navigation bar, a sidebar, a toolbar, a row, a field, a menu, a primary action, an
empty state. The stylesheet has none of those.

The record says the same thing. The three UI mockups in the corpus each invented new
class names on top of that stylesheet, 38, 40 and 58 of them. The ordinary documents
invented 0 to 5. A mockup that links `document.css` argues with it for the whole file and
then wins by overriding it, which is two stylesheets of work for one screen.

A mockup writes its own CSS, in its own file, uploaded as a sibling and linked. `files`
carries `index.html` and `screen.css`. Not a `style` block holding 300 rules. The file is
part of the revision, so an old revision keeps rendering the way it did.

## What you get here

Gradients, glass and blur, display type, a hero, several accents at once, motion,
`border-radius`, and a design language borrowed from a real product are all available.
Build one theme rather than both, whichever the product uses.

Every one of those is banned next door, and the reason is the different job. A document
repeats one structure so the reader learns it once and stops looking at it. A mockup is
looked at and reacted to, not read twice. It is allowed to look like a product, because
looking like a product is the thing the reader is judging.

## What still binds

1. **Pinned `https://esm.sh/` imports only, and no other external host.** Revisions are
   permanent, so an unpinned import is a bug: it changes how an old revision renders
   later.
2. **No web font.** System faces only. A borrowed design language usually names a font
   you may not load, so pick the closest system face and name the substitution in your
   report.
3. **Declare `color-scheme`.** One theme is fine here, so declare the one you built:
   `color-scheme: dark`, not `light dark`, when the page is dark only.
4. **A project-prefixed slug**, as above.
5. **An HTML comment at the top of the file**, before `<!doctype html>`, naming the
   variation and what it tries: `<!-- v2: two-pane, accent on the primary action only,
   no sidebar -->`. It is never rendered, and it is how the reader's note maps back to a
   push.
6. **Real product copy where it exists.** Read the repository for the real strings, the
   real route names, the real button labels. Invented copy is fine when it is plausible.
   `lorem ipsum` never is.
7. **No invented metric.** Sample data in a screen is expected: a list needs rows, a
   chart needs a series. Keep it plausible, and never present a number as a measurement
   of the real system. A made-up 87% is worse than no number.

## Two hard rules, learned this round

**No card inside a card.** If an element carries a fill, a border, or a shadow, nothing
inside it carries its own. Separate the inside with hairlines, space, and position. A
panel inside a panel inside a panel reads as boxes rather than as a product, and it is
the first thing the reader banned.

**No outer window, shell, or frame.** No title bar, no rounded browser chrome, no device
bezel, no card floating on a desktop background. The page is the screen. It runs to the
edges of the viewport.

## Iteration

One slug per direction. Revisions are the history, so push each fix at the same slug and
the reader keeps one URL and can compare.

Simultaneous variations of one screen get their own slugs, `myproject-home-v1` and
`myproject-home-v2`, one push each, with the intent comment at the top of each saying how
that one differs.

A direction that wins is written fresh in the repository, under the project's own rules,
framework, tokens and components. The mockup is never pasted in as the implementation. It
has no states, no keyboard handling, no responsive behaviour you verified, and it
hardcodes colours the project already has tokens for.

## What the reader asks for next

Every round of feedback in the record was one of four. Expect one of these, and answer it
with a second push rather than with a defence of the first.

- **A specific ban.** "No card in card." "No window." Apply it to the whole page, not
  only to the element the reader pointed at.
- **More colour.** The page is too grey. Commit to the accent: use it on a surface, not
  only on a 1px border and a link.
- **More width.** The page is too narrow. Remove the centred column, spend the window,
  add the columns the screen would really have.
- **A named product.** "Make it look like Linear." Take that literally. Find the real
  published token values, the type scale, the spacing step, the exact greys, and use
  those numbers. Do not approximate from memory of a screenshot. Then say in your report
  which values you could not reach, for example a web font you may not load, and what
  you used instead.

## Before you deliver

- [ ] `document.css` is not uploaded and not linked
- [ ] The page's own CSS is a sibling file, uploaded and linked
- [ ] Intent comment at the top of `index.html`, naming the variation and what it tries
- [ ] `color-scheme` declared for the theme you built
- [ ] No element with a fill, a border, or a shadow contains another one
- [ ] No window, shell, bezel, or frame around the page
- [ ] No web font, and no external request other than a pinned `esm.sh` import
- [ ] Real copy where it exists, plausible copy where it does not, no `lorem ipsum`
- [ ] No number presented as a measurement of the real system
- [ ] Project-prefixed slug, one per direction
- [ ] No browser, no local server, and no screenshot was used to check this page
- [ ] The user has the plan.env.md URL, and the report names what you could not reach

## See also

- **`web-design`** for the frontend conventions, and for the same card rule stated for
  product code.
- **`plan-env`** for anything that is a document rather than a design: a plan, a spec, a
  review, findings, an explainer, a comparison.
