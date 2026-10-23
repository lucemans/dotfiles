---
name: theme-round
description: Visual language of 'theme-round' used in (error-menu, metered-usage, plan-env-md). Use when directed.
---

# Theme Round

Slate UI built from filled surfaces. The page is a canvas. Every panel, row, menu and dialog
is a surface on it. A control that must read as editable is raised off its surface.
Nothing top-level draws a box border, only popups, popovers, or dialogs have a light border.

## Tokens (Tailwind v4 `@theme`, copy exactly)

| Token | Light | Dark |
|---|---|---|
| `canvas` | `#f8fafc` | `#000000` |
| `surface` | `#ffffff` | `#141416` |
| `raised` | `#ebeff4` | `#1c1c20` |
| `raised-hover` | `#dfe5ec` | `#27272a` |
| `hairline` | `#e2e8f0` | `#27272a` |
| `radius-panel` | `0.875rem` | same |
| `radius-control` | `0.5rem` | same |

In dark mode, redefine the slate ramp as neutral grey that ends at black: 50 `#fafafa`,
100 `#f4f4f5`, 200 `#e4e4e7`, 300 `#d4d4d8`, 400 `#a1a1a6`, 500 `#78787d`, 600 `#525256`,
700 `#3f3f45`, 800 `#27272a`, 900 `#141416`, 950 `#000000`. The light slate has a blue
tint that looks wrong on black.

Dark mode is class based: `@custom-variant dark (&:where(.dark, .dark *))`. A toggle sets
`html.dark` and stores the choice in `localStorage` under `<app>-theme`. With no stored
choice, follow `prefers-color-scheme`.

## Surfaces

- There are three levels: canvas, then surface, then raised. Never put a surface inside
  a surface. Split the inside of a panel with space or a `hairline` rule.
- A border is only allowed for hairline separators and the active tab underline
  (`border-b-2`). There are no outlined boxes.
- A shadow is only allowed on floating layers: menus and dialogs use
  `rounded-panel bg-surface p-1 shadow-xl`.
- Selection and hover inside a list or menu use `bg-raised`.

## Layout

- Header: no fill, `max-w-5xl mx-auto px-6 py-2`. Brand on the left: a 24px mark plus a
  `text-sm font-semibold tracking-tight` name. A `/` separator in `slate-300` (dark
  `slate-600`), then a scope switcher. Glyph buttons and the account menu on the right.
- Main: `max-w-5xl mx-auto px-6 py-8`.
- Page header: a 40px mark, then `h1 text-lg font-semibold`, a `text-sm text-slate-500`
  line under it, and actions aligned right.

## Type

- System sans only. Body is `text-sm`. Page titles are `text-lg`. Nothing is larger
  unless it is one key number.
- Tertiary text is `slate-500` (dark `slate-400`). Secondary is `slate-600` (dark `slate-300`).
- Small labels: `text-xs font-medium uppercase tracking-wide text-slate-500`.
- Numbers use `tabular-nums`.

## Controls

- Primary button: `rounded-control bg-slate-900 px-3 py-1.5 text-sm font-medium
  text-white hover:bg-slate-700`, inverted in dark mode (`bg-slate-100 text-slate-900`).
  Use one per view.
- Secondary button or menu trigger: `rounded-control bg-raised px-3 py-1.5 text-sm
  font-medium text-slate-700 hover:bg-raised-hover`.
- Glyph button: `size-8 rounded-control`, no fill until hover (`hover:bg-raised`), with a
  16px Feather icon (`solid-icons/fi`).
- Inputs sit on `bg-raised` with no border.
- Tooltips are inverted: `bg-slate-900 text-white text-xs rounded-control`.
- Behaviour comes from Kobalte primitives. Set the pointer cursor once in `@layer base`,
  and `not-allowed` for disabled items.

## Colour means status only

| Meaning | Text | Fill |
|---|---|---|
| Good, added | `emerald-700` / dark `emerald-400` | `emerald-50` / dark `emerald-950/40` |
| Medium, changed | `amber-700` / dark `amber-400` | `amber-50` / dark `amber-950/40` |
| Bad, removed | `red-700` / dark `red-400` | `red-50` / dark `red-950/40` |
| Low, upgraded | `sky-700` / dark `sky-400` | `sky-50` / dark `sky-950/40` |
| Neutral | `slate-500` | `bg-raised` |

- Solid dots and bars use the `-500` step.
- Show status as a dot or icon next to a word, or as one tinted `rounded-panel` block.
  Never as a coloured outline.
- There is no brand accent colour. The slate-900 primary button is the accent.

## Data display

- Count columns get fixed-width slots (`w-12`) so a column of rows reads straight down.
  Leave the slot empty when the value is zero.
- Proportion bars: `h-1.5 rounded-full` on `slate-100` (dark `slate-800`), with one
  `-500` segment per kind.

## Copy

Short sentence-case labels. Present tense while something is in progress
("Discovering...", "Signing out..."). Errors in `red-600` with `role="alert"`, status
lines with `role="status"`.
