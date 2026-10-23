---
name: teach-me
description: Build a multi-tab interactive crash course as one hosted HTML page, for a programmer who wants to learn a technical topic without formal maths notation. Use when the user says "teach me X", "crash course on X", "explain X with demos", or asks for a Jupyter-notebook-style learning page. Pairs with plan-env for hosting and the answer loop.
disable-model-invocation: true
---

# Interactive course

You build a course: one HTML page with one tab per concept. Every tab has short prose, real code, and demos that run real computation in the browser. The reader answers a question at the end of each tab. You read the answers and publish a new revision. The course improves over several rounds, so plan for that from the first push.

The reader is an application developer. They read code fluently and build real systems. They do not read maths notation, and they switch off at textbook language. Your job is to turn every idea into something a programmer can run in their head.

Read `skill://plan-env` before you start. It owns hosting, the stylesheet, the question mechanism and the rules about the page. This skill adds what plan-env does not cover: how to teach.

## 1. Calibrate before you build

Do not guess the reader's level. Before any markup, call the `ask` tool with 6 to 10 sample sentences, one per major concept, spread from the easy end of the topic to the hard end. Each question has three options: Clear, Roughly, Lost.

```
"A hash is a one-way function: you can compute keccak256(x) instantly, but given
the output there is no faster way to find x than guessing inputs."
  Clear / Roughly / Lost
```

Write each sample sentence in your normal textbook voice on purpose. The answers tell you which concepts need depth and which only need a short recap. Add one question about delivery (hosted page or local project) if that is not settled.

Treat the calibration as a lower bound on difficulty, not an upper one. In the reference course the reader marked "EC multiply" as Clear and then got lost on the curve tab. Understanding a sentence is not the same as following a whole page.

## 2. The writing style

This section matters more than the demos. Every rule here was learned from a reader who got lost.

### Write like a code walkthrough

The target voice:

> `chainSecret` is any 32-byte value. `step1 = sha256(chainSecret)`. Keep hashing until `step15`, and publish that as `chainPublicKey`. To sign the digit 6, send `step6`. The verifier hashes it 9 more times and compares with `chainPublicKey`.

The voice that loses the reader:

> Consider the universe U of all 8-bit strings, and a function f mapping each element of the set to...

Rules:

- **Name every value like a variable.** `pointA`, `privateKey`, `messageHash`, `signatureR`, `runningPoint`, `witness.xSquared`. Never a single letter inside a formula: not `A`, `d`, `k`, `s`, `w`, `τ`. If a real library uses a short name, say so once: "In `lib.js`, `k` is `privateKey`."
- **Write formulas as code.** `witness.x * witness.x === witness.xSquared`, not `x² = v₁`. Use `*`, `===`, `%`, function calls. Use `mul(privateKey, basePoint)`, not `d·G`.
- **Plain phrasing for sets and probability.** "It can be any 8-bit value", not "an element of the set of 8-bit strings". "1 in 1,048,576", not "negligible probability". "Tries", not "queries to the oracle".
- **The idea first, the name last, or never.** "This format is called R1CS. You do not need the name." A reader can hold an idea without its name. They cannot hold a name without its idea.
- **One idea per sentence. Short paragraphs.** Dense paragraphs were one of the three causes the reader named for getting lost.
- **Show every step with real numbers.** "81 wraps to 81 - 4 * 17 = 13." "`y * y % 17 = 64 % 17 = 13`."
- **Explain with things programmers already know.** `uint8` wrap-around for modular arithmetic. Building 345 from its decimal digits before building 45 from its binary digits. `x + y = 10` before "one equation with two unknowns". 12 / 4 = 3 remainder 0 before polynomial division. A locked box for a curve point.
- **Plain objects before abstract ones.** Do the loop on numbers, then the same loop on points. Do the list comparison, then the polynomial version.
- **Push internals into an "Optional:" section** at the end of a tab. Say at the top of it: "You never need this section to use `add`."
- **Explain every visual element.** If a chart shows blue, grey and green dots, add a table: dot, what it is. A reader who does not know why a dot appears stops trusting the chart. Then explain *why* the mechanism works that way, and give a toggle that turns the reason off (see section 4).
- **Say why it matters.** Each tab ends by naming what the idea unlocks later, and linking there.
- **Link real-world anchors the reader cares about.** Real incidents (Sony PS3 nonce reuse, the Tornado circom bug). Standards their colleagues use (FIPS 205, SP 800-208). Ethereum specifics (precompile addresses, gas costs). Ask or infer what the reader's world is and tie to it.

### Answer the reader in their own words

When the reader writes a note on a tab, quote it in full at the top of the rewritten tab, then answer it point by point with a verdict per point: right, small fix, missing piece. A reader who wrote a half-correct model learns more from "your model is mostly right, here are the two gaps" than from a fresh explanation.

## 3. Page structure

Shape: plan-env **explainer**, with tabs.

- **Tabs.** Each concept is one `section.tab` with an `id` like `t-curves`. The sidebar `nav.toc` holds one `a.tab-link` per tab, grouped by theme. `document.css` swaps tabs with `:target`; with no hash, every tab shows, so the page still reads top to bottom. Add a small script that redirects an empty hash to the first tab, sets `aria-current` on the active link, and scrolls to the top on `hashchange`.
- **IDs.** Number tabs `00`, `01`, `02`. When a concept grows, split it with letter suffixes (`02`, `02b`, `02c`, `02d`) so existing numbers and question keys stay stable. Widen `.chip` and `nav.toc em` to `width: auto` for three-character IDs.
- **Order.** Each tab uses only the tabs above it. Build the ladder from the most concrete primitive up to the real system the reader asked about.
- **Map tab (00).** Contains:
  - the whole course in about six sentences
  - a table: tab, the idea in one line, what it unlocks later
  - the colour legend
  - a "toy versus real" table: every place a demo shrinks a parameter or uses a stand-in, and why the lesson still holds
  - "What changed in revision N", newest first, naming the reader's feedback that caused each change
  - "What I checked", saying exactly what you ran and what you did not verify
- **Each tab:**
  1. `h1` with the chip and title
  2. `.lede`: the one idea to keep, in one or two sentences
  3. `h2` steps, each short, with a code snippet where it helps
  4. demos in a `.lab` block, placed right after the prose they illustrate
  5. a closing paragraph with `id="<tab>-end"` that states what the tab unlocked and links forward; the tab's question anchors here
  6. back and next links
- **Code snippets.** `figure.snippet` with `data-lang`. Mark invented code "illustrative" in the caption. Quote real source exactly with `repo path:line-range`. Use the reader's language (TypeScript for a web developer).
- **Sources** at the end of the last tab, with what you actually read and what you only found through search.

## 4. Demos

Aim for two or more demos per tab, and more on tabs the reader found hard. Visualisations count. A demo is not decoration: each one must let the reader *do* the idea, or *break* it.

### The demo kinds that worked

| Kind | Example | Why it teaches |
|---|---|---|
| **Attack demo** | Sign twice with Lamport, then forge. Reuse an ECDSA nonce, then recover the key. Crack an unsalted commitment by guessing. | The reader sees *why* a rule exists by breaking it. |
| **Toggle the reason off** | "no checksum" on Winternitz. "skip the flip" on curve addition. "delete this constraint" on circom `IsZero`. | Shows what the mechanism protects against. The reader asked "why the flip?" and this answered it. |
| **Step player** | `mul` double-and-add: next step, play, start over. A `dl.vars` list shows every variable (`privateKey` with the current bit highlighted, `runningNumber`, `runningPoint`, `stepsDone`) and an `ol.trace` logs each step. | Makes a loop visible. Always show the plain-number twin variable next to the abstract one. |
| **Plain-number twin** | Build 45 from `101101` by doubling and adding 1, in a table, before the same loop on points. | Gives a model to map the abstract version onto. |
| **Side-by-side game** | Guess `x` from `2^x` (gives "too big / too small") against guessing on a clock (no hint). | Contrast teaches a property faster than a definition. |
| **Click to inspect** | Click any dot on a 17×17 grid and see both sides of the curve check with real numbers. | Turns a rule into arithmetic you can check. |
| **Drag to feel** | Drag one point of a polynomial and watch the whole curve move. | Builds intuition for "small change, big effect". |
| **Exhaustive check** | Compare two lists by trying every `x` from 0 to 96 and counting where their curves agree. | Replaces a probability claim with a count. |
| **Chained state** | The witness typed on tab 09 feeds the polynomial demos on tab 10. | Shows that the tabs are one pipeline, not separate lessons. |
| **Calculator on real parameters** | SLH-DSA signature size from the real parameter table, split into its parts. | Connects the toy to the standard. |
| **Simulator** | A small Tornado pool: deposits, withdrawals, double spend, front-running bot, the on-chain event log. | The capstone. Every earlier idea appears in one place. |

### Rules for demos

- **Real computation.** Implement the primitives from scratch in a shared `lib.js`: hash, modular arithmetic with `BigInt`, curve add and mul, Merkle trees, polynomial interpolate and divide. No libraries. The demo is honest only if the math is real.
- **Shrink parameters, not logic.** Use a 16-bit digest, numbers mod 97, a tree of 8 leaves, so the effect shows in a second. List every stand-in in the "toy versus real" table. Where the real size is cheap (secp256k1 key generation), use it.
- **Label a toy as a toy** inside the demo when it cheats, as with a pairing that reads the hidden numbers directly.
- **Use the same variable names** in the demo output as in the prose. If the prose says `signatureR`, the demo prints `signatureR =`.
- **Fallback text.** Every output element holds text like "With scripts enabled, the result shows here." so the page reads without scripts.
- **Colour means one thing on every tab.** In the reference course: amber = secret, teal = public, blue = in focus, green = passes, red = fails or attack works. Name the binding once in a `.legend` on the map tab.
- **Canvas, not a chart library,** for anything with geometry or custom drawing. Use a chart library only for data plots.

### Code organisation

```
index.html        prose, tabs, all markup and demo controls
document.css      plan-env, verbatim
code.css code.js  plan-env snippet highlighting, verbatim
lib.js            primitives + shared DOM and canvas helpers
demo-<group>.js   one module per group of tabs, one block { } per demo
```

Each demo is a block scope in its module that finds its elements by id and wires its handlers. Keep `lib.js` free of demo logic.

The canvas helper that made every canvas work in hidden tabs, at device resolution, in both themes:

```js
// Colours come from the page tokens through a probe element, because a custom
// property holding light-dark() reads back as its unresolved source text.
const probe = document.createElement("span");
export const cssColor = (name) => {
  if (!probe.isConnected) { probe.style.display = "none"; document.body.append(probe); }
  probe.style.color = `var(${name})`;
  return getComputedStyle(probe).color;
};

const redrawers = new Set();
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => redrawers.forEach((f) => f()));

// Sizes a canvas to its CSS box and redraws whenever the box changes, which
// includes the moment a hidden tab becomes visible.
export const mountCanvas = (canvas, height, draw) => {
  const ctx = canvas.getContext("2d");
  canvas.style.width = "100%";
  canvas.style.height = `${height}px`;
  const render = () => {
    const w = canvas.clientWidth;
    if (w === 0) return;
    const dpr = devicePixelRatio || 1;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, height);
    draw(ctx, w, height, palette());   // palette() maps role names to cssColor(token)
  };
  new ResizeObserver(render).observe(canvas);
  redrawers.add(render);
  return { render };
};
```

Also keep a tiny `el(tag, props, ...children)` helper for building output, and `$`/`$$` selectors.

## 5. Verify without a browser

plan-env forbids opening the page yourself. Verify in Node instead:

1. **Primitive tests.** Check `lib.js` against known vectors: SHA-256 against `node:crypto` across padding edge cases, a known curve point, a sign-verify round trip, attack recovery, polynomial divide with and without a remainder.
2. **Stub-DOM smoke test.** Define minimal `document`, `window`, `getComputedStyle` and `ResizeObserver` stubs. The canvas context is a Proxy that returns no-ops, plus `measureText` returning a width. Parse initial input values out of `index.html`. Import every demo module, then fire every registered handler. Assert on the text each demo produces: "forgery accepted", "same point", "agree at only 3 of 97". The `ResizeObserver` stub must call back asynchronously, or a canvas draws before its state exists.
3. **Id cross-check.** Every `$("#id")` in the demo modules exists in `index.html`, and no id repeats.
4. **Cross-demo agreement.** When two demos show the same thing, check they agree: the step player and `lib.js` land on the same point, and the number table and the point loop take the same number of steps.
5. **Grep** for em-dashes and leftover single-letter notation after each rewrite.

Write in the page what you ran and what you did not verify. Parameter tables typed from memory must say so.

## 6. The revision loop

Push with plan-env. Every tab gets one question anchored at `<tab>-end`:

```
key: land-<tab>      prompt: "Did the <Tab> tab land?"
options: Clear / Roughly / Lost / Too basic
```

The reader can add a free-text note to any answer. The notes are the most valuable signal you get. Read them with `plan_answers` when the user says they answered.

- **Rewrite exactly where the reader stopped.** Notes like "you lost me at 'Demo: watch mul'" or a quoted paragraph point to the sentence that failed. Rewrite from that point, and add a plainer step or demo before it.
- **Re-key a rewritten tab's question** (`land-curves-v2`, `-v3`) so the old answer does not describe the new text. Carry every other question forward unchanged: a push that omits a question clears its answer.
- **Ask for the cause once** when several tabs fail together: a multi-select question with causes such as too many symbols, too many new words, dense paragraphs, unclear demos, no clear why, too fast. Then apply the answer to every tab, not only the failed ones.
- **Convert ahead of the reader.** When a style fix lands, convert the tabs the reader has not reached yet, so they do not hit the old style.
- **Sidebar progress.** Mark tabs green (`a.tab-link.done`, `--pos`) when the reader answered Clear or Roughly and the tab has not changed since. A rewritten tab loses its green until the reader answers again. Explain the green in a note at the top of the sidebar and in the legend.
- **Log every revision** on the map tab: what the reader said, what changed.
- **Report in chat** per revision: what the answers said, what changed per tab, what you verified, what stays open.

## 7. Mistakes that cost a revision

- Textbook voice in the first draft. Start plain; do not wait for the reader to ask.
- Single letters in formulas (`d·G`, `(z + r·d)/k`). Use `mul(privateKey, basePoint)`.
- A chart that shows several kinds of element without saying what each one is.
- Explaining *what* a mechanism does but not *why* it is built that way.
- Jumping to the abstract version (points, polynomials) with no plain-number version first.
- Introducing the storage format (coefficient vectors) before the rule it stores.
- A rewrite that reorders concepts the reader had already understood. On a rewrite, keep what landed and fix only the gap.
- Stating a probability instead of letting a demo count it.
- Shipping an idea without a demo on a tab the reader found hard. More demos fix hard tabs more reliably than more prose.
