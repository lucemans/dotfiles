import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { copyToClipboard } from "@oh-my-pi/pi-coding-agent/utils/clipboard";
import {
  type Component,
  highlightCode,
  lexDocument,
  matchesKey,
  replaceTabs,
  type Theme,
  type TUI,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
} from "@oh-my-pi/pi-tui";
import type { Token } from "@oh-my-pi/pi-utils/marked";

// OMP wraps code rows itself, so a mouse selection copies its wrap points as
// newlines. This copies the block source instead. The picker takes the place
// of the editor, so the conversation above it stays visible and scrollable.

type CodeBlock = { lang: string; code: string };

const previewRows = 12;
const pageStep = 5;

const codeBlocks = (tokens: readonly Token[]): CodeBlock[] =>
  tokens.flatMap((token): CodeBlock[] => {
    switch (token.type) {
      case "code":
        return [{ lang: token.lang ?? "", code: token.text }];
      case "list":
        return token.items.flatMap((item) => codeBlocks(item.tokens));
      case "blockquote":
        return codeBlocks(token.tokens);
      default:
        return [];
    }
  });

// Wrapped for display only; the copy takes the source.
const preview = (block: CodeBlock, inner: number, theme: Theme): string[] => {
  const styled = block.lang ? highlightCode(block.code, block.lang) : block.code.split("\n");
  const rows = styled.flatMap((row) => wrapTextWithAnsi(replaceTabs(row), inner));
  if (rows.length <= previewRows) return rows;
  return [...rows.slice(0, previewRows), theme.fg("dim", `… +${rows.length - previewRows} more rows`)];
};

const outline = (rows: readonly string[], inner: number, theme: Theme): string[] => {
  const side = theme.fg("success", theme.boxDotted.vertical);
  const horizontal = theme.boxDotted.horizontal.repeat(inner + 2);
  return [
    theme.fg("success", theme.boxRound.topLeft + horizontal + theme.boxRound.topRight),
    ...rows.map((row) => `${side} ${row}${" ".repeat(Math.max(0, inner - visibleWidth(row)))} ${side}`),
    theme.fg("success", theme.boxRound.bottomLeft + horizontal + theme.boxRound.bottomRight),
  ];
};

const picker = (
  blocks: readonly CodeBlock[],
  tui: TUI,
  theme: Theme,
  done: (block: CodeBlock | undefined) => void,
): Component => {
  let selected = 0;
  let top = 0;
  let previews: { inner: number; rows: string[][] } | undefined;

  const move = (delta: number): void => {
    selected = Math.min(blocks.length - 1, Math.max(0, selected + delta));
    tui.requestRender();
  };

  return {
    render(width) {
      const inner = Math.max(10, width - 4);
      if (previews?.inner !== inner) {
        previews = { inner, rows: blocks.map((block) => preview(block, inner, theme)) };
      }

      const lines: string[] = [];
      let selStart = 0;
      let selEnd = 0;
      blocks.forEach((block, index) => {
        const isSelected = index === selected;
        const count = block.code.split("\n").length;
        const caption = truncateToWidth(
          `${index + 1}/${blocks.length}${theme.sep.dot}${block.lang || "text"}${theme.sep.dot}${count} ${count === 1 ? "line" : "lines"}`,
          inner,
        );
        const rows = previews?.rows[index] ?? [];
        lines.push("");
        if (isSelected) selStart = lines.length;
        lines.push(`  ${theme.fg(isSelected ? "success" : "dim", caption)}`);
        lines.push(...(isSelected ? outline(rows, inner, theme) : rows.map((row) => `  ${row}`)));
        if (isSelected) selEnd = lines.length;
      });

      const height = Math.max(6, Math.floor(tui.terminal.rows * 0.45));
      if (selEnd - top > height) top = Math.min(selStart, selEnd - height);
      if (selStart < top) top = selStart;
      top = Math.max(0, Math.min(top, lines.length - height));
      const body = lines.slice(top, top + height);
      while (body.length < height) body.push("");

      return [
        `${theme.cmd.copy} ${theme.bold("Yoink")}${theme.sep.dot}${theme.fg("dim", "pick a code block to copy")}`,
        ...body,
        theme.fg("dim", `${selected + 1}/${blocks.length}  ↑/↓ block  PgUp/PgDn jump  enter copy  esc close`),
      ];
    },
    handleInput(data) {
      if (matchesKey(data, "up")) move(-1);
      else if (matchesKey(data, "down")) move(1);
      else if (matchesKey(data, "pageUp")) move(-pageStep);
      else if (matchesKey(data, "pageDown")) move(pageStep);
      else if (matchesKey(data, "enter")) done(blocks[selected]);
      else if (matchesKey(data, "escape")) done(undefined);
    },
  };
};

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("yoink", {
    description: "Pick a code block from the conversation, newest first, and copy its source",
    handler: async (_args, ctx) => {
      const blocks = ctx.sessionManager
        .getBranch()
        .flatMap((entry) =>
          entry.type === "message" && entry.message.role === "assistant"
            ? codeBlocks(
                lexDocument(
                  entry.message.content
                    .flatMap((part) => (part.type === "text" ? [part.text] : []))
                    .join("\n\n"),
                ),
              )
            : [],
        )
        .reverse();
      if (blocks.length === 0) {
        ctx.ui.notify("No code block in this conversation", "warning");
        return;
      }

      const block = await ctx.ui.custom<CodeBlock | undefined>((tui, theme, _keybindings, done) =>
        picker(blocks, tui, theme, done),
      );
      if (block === undefined) return;

      await copyToClipboard(block.code);
      ctx.ui.notify(`Copied ${block.lang || "code"} block to the clipboard`, "info");
    },
  });
}
