// plan-env highlight runtime.
// Inline verbatim as the last module script in the document body.
// The language comes from data-lang on the figure, which is the one place a
// snippet declares it. A block whose language is not in GRAMMARS, and any
// is-diff block, is left as written.
import { createHighlighterCore } from "https://esm.sh/@shikijs/core@4.4.3";
import { createJavaScriptRegexEngine } from "https://esm.sh/@shikijs/engine-javascript@4.4.3";
import {
  transformerNotationDiff,
  transformerNotationHighlight,
  transformerNotationFocus,
  transformerNotationWordHighlight,
  transformerNotationErrorLevel,
} from "https://esm.sh/@shikijs/transformers@4.4.3";

const GRAMMARS = {
  typescript: () => import("https://esm.sh/@shikijs/langs@4.4.3/typescript"),
  javascript: () => import("https://esm.sh/@shikijs/langs@4.4.3/javascript"),
  rust: () => import("https://esm.sh/@shikijs/langs@4.4.3/rust"),
  nix: () => import("https://esm.sh/@shikijs/langs@4.4.3/nix"),
  bash: () => import("https://esm.sh/@shikijs/langs@4.4.3/bash"),
  json: () => import("https://esm.sh/@shikijs/langs@4.4.3/json"),
  css: () => import("https://esm.sh/@shikijs/langs@4.4.3/css"),
  html: () => import("https://esm.sh/@shikijs/langs@4.4.3/html"),
  solidity: () => import("https://esm.sh/@shikijs/langs@4.4.3/solidity"),
};

const blocks = [...document.querySelectorAll(".snippet[data-lang]:not(.is-diff) pre > code")]
  .map((el) => ({ el, lang: el.closest(".snippet").dataset.lang }))
  .filter(({ lang }) => lang === "ansi" || lang in GRAMMARS);

if (blocks.length) {
  const wanted = [...new Set(blocks.map((b) => b.lang))].filter((lang) => lang in GRAMMARS);

  const highlighter = await createHighlighterCore({
    themes: [
      import("https://esm.sh/@shikijs/themes@4.4.3/github-light"),
      import("https://esm.sh/@shikijs/themes@4.4.3/github-dark"),
    ],
    langs: wanted.map((lang) => GRAMMARS[lang]()),
    engine: createJavaScriptRegexEngine(),
  });

  for (const { el, lang } of blocks) {
    el.closest("pre").outerHTML = highlighter.codeToHtml(el.textContent, {
      lang,
      themes: { light: "github-light", dark: "github-dark" },
      defaultColor: false,
      transformers: [
        transformerNotationDiff(),
        transformerNotationHighlight(),
        transformerNotationFocus(),
        transformerNotationWordHighlight(),
        transformerNotationErrorLevel(),
      ],
    });
  }
}
