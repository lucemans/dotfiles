// plan-env highlight runtime.
// Upload beside index.html and load it as a module.
// The language comes from data-lang on the figure, which is the one place a
// snippet declares it. A block whose language is not in GRAMMARS is left as
// written.
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
  lua: () => import("https://esm.sh/@shikijs/langs@4.4.3/lua"),
  markdown: () => import("https://esm.sh/@shikijs/langs@4.4.3/markdown"),
  bash: () => import("https://esm.sh/@shikijs/langs@4.4.3/bash"),
  json: () => import("https://esm.sh/@shikijs/langs@4.4.3/json"),
  css: () => import("https://esm.sh/@shikijs/langs@4.4.3/css"),
  html: () => import("https://esm.sh/@shikijs/langs@4.4.3/html"),
  solidity: () => import("https://esm.sh/@shikijs/langs@4.4.3/solidity"),
};

const THEMES = { light: "github-light", dark: "github-dark" };

const NOTATION = [
  transformerNotationDiff(),
  transformerNotationHighlight(),
  transformerNotationFocus(),
  transformerNotationWordHighlight(),
  transformerNotationErrorLevel(),
];

const figures = [...document.querySelectorAll(".snippet[data-lang]")]
  .filter((figure) => figure.dataset.lang === "ansi" || figure.dataset.lang in GRAMMARS);

// a line node carries its class as a string or as an array, depending on which
// transformer reached it first
const addClass = (node, ...names) => {
  const current = node.properties.class;
  const existing = Array.isArray(current) ? current : String(current ?? "").split(" ");
  node.properties.class = [...existing, ...names].filter(Boolean).join(" ");
};

// A hand written diff owns which lines changed; the highlighter only colours
// the text. The ins and del elements are read before the block is replaced, so
// the same page still marks the change with scripts disabled.
const handDiffLines = (pre) =>
  [...pre.children].flatMap((element) => {
    const kind = { INS: "add", DEL: "remove" }[element.tagName] ?? null;
    return element.textContent.replace(/\n$/, "").split("\n").map((text) => ({ text, kind }));
  });

const transformerHandDiff = (kinds) => ({
  name: "planenv-hand-diff",
  line(node, line) {
    if (kinds[line - 1]) addClass(node, "diff", kinds[line - 1]);
  },
});

if (figures.length) {
  const wanted = [...new Set(figures.map((figure) => figure.dataset.lang))]
    .filter((lang) => lang in GRAMMARS);

  const highlighter = await createHighlighterCore({
    themes: [
      import("https://esm.sh/@shikijs/themes@4.4.3/github-light"),
      import("https://esm.sh/@shikijs/themes@4.4.3/github-dark"),
    ],
    langs: wanted.map((lang) => GRAMMARS[lang]()),
    engine: createJavaScriptRegexEngine(),
  });

  const render = (source, lang, transformers) =>
    highlighter.codeToHtml(source, { lang, themes: THEMES, defaultColor: false, transformers });

  // A terminal keeps its own markup: the $ prompt comes from CSS on .cmds code,
  // and one .cmds block holds one code element per command. Replacing the pre
  // would drop both, so each command is coloured where it stands.
  const colourInPlace = (code, lang) => {
    const holder = document.createElement("template");
    holder.innerHTML = render(code.textContent, lang, []);
    const line = holder.content.querySelector(".line");

    if (!line) return;

    code.replaceChildren(...line.childNodes);
    code.classList.add("shiki");
  };

  for (const figure of figures) {
    const lang = figure.dataset.lang;

    if (figure.classList.contains("is-diff")) {
      const lines = handDiffLines(figure.querySelector("pre"));

      figure.querySelector("pre").outerHTML = render(
        lines.map((line) => line.text).join("\n"),
        lang,
        [transformerHandDiff(lines.map((line) => line.kind))],
      );
      continue;
    }

    for (const pre of [...figure.querySelectorAll("pre")]) {
      const codes = [...pre.children].filter((child) => child.tagName === "CODE");

      if (codes.length === 0) continue;

      if (pre.classList.contains("cmds")) {
        for (const code of codes) colourInPlace(code, lang);
        continue;
      }

      pre.outerHTML = render(codes[0].textContent, lang, NOTATION);
    }
  }
}
