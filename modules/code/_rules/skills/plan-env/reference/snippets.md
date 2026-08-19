# Code snippets

Every code block longer than one line uses this layout. Do not write snippet styles or a
highlight runtime per document. Inline `reference/code.css` into the stylesheet and
`reference/code.js` as the last module script, both verbatim. They need the tokens from
the base stylesheet in SKILL.md section 3: `--panel`, `--code-bg`, `--rule`, `--radius`,
`--mono`, `--ink-soft`, `--ink-faint`, `--accent`, `--accent-soft`, `--pos`, `--pos-soft`,
`--neg`, `--neg-soft`.

## Layout

A `figure.snippet`, a `figcaption` header row, then the `pre`. The header names the
source: quoted code gets `path:line-range`, new or illustrative code gets a short title.
The language tag sits at the right end. The field order never changes.

```
<figure class="snippet">
  <figcaption><code>src/server.ts:12-24</code><span class="lang">typescript</span></figcaption>
  <pre><code class="language-typescript">...</code></pre>
</figure>
```

Content fidelity applies inside a snippet: quote exactly, escape exactly, elide nothing.

## Highlighting

Runs at read time with Shiki, pinned inside `reference/code.js`. Supported languages:
`typescript`, `javascript`, `rust`, `nix`, `bash`, `json`, `css`, `solidity`, `ansi`.
Any other language renders plain. Do not add grammars per document.

The page must read fully with scripts disabled. Highlighting decorates text that is
already in the HTML. Never build a snippet whose content arrives by script.

## Notation markers

Vary a snippet only through these. Write the marker as a comment in the language's own
comment syntax, on the affected line. The runtime strips it and applies the effect. With
scripts disabled the marker text stays visible, which is acceptable. An invented marker
is not.

| Effect | Marker |
| --- | --- |
| Emphasize a line | `// [!code highlight]` |
| Dim everything except the marked lines | `// [!code focus]` |
| Added and removed lines in illustrative code | `// [!code ++]` and `// [!code --]` |
| Emphasize one word | `// [!code word:port]` |
| Mark the failing or suspect line | `// [!code error]`, `// [!code warning]` |

Notation diff is for illustration. A proposed change to a real file uses the diff rules
in SKILL.md rule 39 instead.

## Variants

**Line numbers.** Add class `numbered` to the figure, only when the prose refers to line
positions.

**Program output with color.** `language-ansi`, keeping the raw escape codes.

**Terminal exchange.** Class `is-terminal` on the figure. Commands are `code` lines
inside one `pre` with class `cmds`. Output follows as its own `pre` holding `samp` or
`language-ansi` content. The `$` prompt comes from CSS and is never part of the text, so
copied commands stay runnable.

```
<figure class="snippet is-terminal">
  <figcaption><code>build</code><span class="lang">bash</span></figcaption>
  <pre class="cmds"><code>pnpm build</code></pre>
  <pre><samp>done in 4.2s</samp></pre>
</figure>
```

**Alternatives shown once** (package managers, platforms). Class `is-group` on the
figure. Hidden radio inputs first, then the `figcaption` with one `label` per alternative
inside its `.tabs` span, then one `section` per alternative in the same order. CSS-only,
works without scripts. Up to four alternatives.

```
<figure class="snippet is-group">
  <input type="radio" name="g1" id="g1a" checked><input type="radio" name="g1" id="g1b">
  <figcaption><span class="tabs"><label for="g1a">pnpm</label><label for="g1b">npm</label></span><span class="lang">bash</span></figcaption>
  <section><pre><code class="language-bash">pnpm add solid-js</code></pre></section>
  <section><pre><code class="language-bash">npm i solid-js</code></pre></section>
</figure>
```
