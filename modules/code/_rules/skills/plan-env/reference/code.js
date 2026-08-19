// plan-env highlight runtime.
// Inline verbatim as the last module script in the document body.
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
  solidity: () => import("https://esm.sh/@shikijs/langs@4.4.3/solidity"),
};

const langOf = (el) => /language-([\w-]+)/.exec(el.className)?.[1];
const blocks = [...document.querySelectorAll("pre > code[class*='language-']")]
  .filter((el) => langOf(el) === "ansi" || langOf(el) in GRAMMARS);

const wanted = [...new Set(blocks.map(langOf))].filter((lang) => lang in GRAMMARS);

const highlighter = await createHighlighterCore({
  themes: [
    import("https://esm.sh/@shikijs/themes@4.4.3/github-light"),
    import("https://esm.sh/@shikijs/themes@4.4.3/github-dark"),
  ],
  langs: wanted.map((lang) => GRAMMARS[lang]()),
  engine: createJavaScriptRegexEngine(),
});

for (const el of blocks) {
  const html = highlighter.codeToHtml(el.textContent, {
    lang: langOf(el),
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
  el.closest("pre").outerHTML = html;
}
