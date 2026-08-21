# Code snippets

One component covers every code shaped block: a quoted snippet, a terminal exchange, and a
proposed file change.

Upload `reference/code.css` and `reference/code.js` beside `index.html`, verbatim, and
link them. `code.css` reads the tokens from `document.css`, so link it second. `code.js`
is a module, so load it with `<script type="module" src="code.js"></script>`.

## Layout

```html
<figure class="snippet" data-lang="rust">
  <figcaption>src/net/retry.rs:41-58</figcaption>
  <pre><code>...</code></pre>
</figure>
```

The language is declared once, in `data-lang` on the figure. The runtime reads it from
there, and the language tag at the right of the caption is drawn from it by CSS. Do not
put a `language-*` class on the `code`, and do not write the language a second time as
text.

The caption names the source. Quoted code gets `path:line-range`. New or illustrative code
gets a short title. Content fidelity applies inside a snippet: quote exactly, escape
exactly, elide nothing.

## Highlighting

Runs at read time with Shiki, pinned inside `code.js`. Supported: `typescript`,
`javascript`, `rust`, `nix`, `lua`, `markdown`, `bash`, `json`, `css`, `html`,
`solidity`, `ansi`. Any other value renders plain. Do not add grammars per document.

Syntax colour comes from the language, not from the page. It sits outside the one hue one
meaning rule in SKILL.md section 4, because a code block is quoted material rather than a
signal the document is sending.

The page must read fully with scripts disabled. Highlighting decorates text that is
already in the HTML. Never build a snippet whose content arrives by script.

## Notation markers

Vary a snippet only through these. Write the marker as a comment in the language's own
comment syntax, on the affected line. The runtime strips it and applies the effect. With
scripts disabled the marker text stays visible, which is acceptable but is a reason to use
them sparingly. An invented marker is not acceptable.

| Effect | Marker |
| --- | --- |
| Emphasize a line | `// [!code highlight]` |
| Dim everything except the marked lines | `// [!code focus]` |
| Added and removed lines in illustrative code | `// [!code ++]` and `// [!code --]` |
| Emphasize one word | `// [!code word:port]` |
| Mark the failing or suspect line | `// [!code error]`, `// [!code warning]` |

Notation diff is for illustration only. A change to a real file uses `is-diff` below.

## Variants

**Proposed file change.** Class `is-diff`. One `ins`, `del`, or `span` per line, written by
hand. Those three elements are the only thing that says which lines changed; the runtime
reads them and colours the text, so write one per line and nothing else. The caption
carries the path and the line range. Quote removed lines exactly from the current file,
and include one or two unchanged lines when they locate the edit. If you have not read
that file, say so instead of reconstructing it.

```html
<figure class="snippet is-diff" data-lang="css">
  <figcaption>reference/document.css:118-121, proposed</figcaption>
  <pre><span>.tree ul ul {</span><del>  margin-left: .6rem;</del><ins>  margin-left: var(--icon-c);</ins><span>}</span></pre>
</figure>
```

**Line numbers.** Add class `numbered`, only when the prose refers to line positions.

**Program output with colour.** `data-lang="ansi"`, keeping the raw escape codes.

**Terminal exchange.** Class `is-terminal`. Commands are `code` lines inside one `pre` with
class `cmds`. Output follows as its own `pre` holding `samp` or `ansi` content. The `$`
prompt comes from CSS and is never part of the text, so copied commands stay runnable.

```html
<figure class="snippet is-terminal" data-lang="bash">
  <figcaption>build</figcaption>
  <pre class="cmds"><code>pnpm build</code></pre>
  <pre><samp>done in 4.2s</samp></pre>
</figure>
```
