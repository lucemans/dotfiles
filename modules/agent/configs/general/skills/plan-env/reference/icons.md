# Icons

Two kinds, with opposite rules. File type icons in a tree: one per row, always. Interface
glyphs in prose: almost never.

## File type icons

`reference/icons.svg` holds 45 prepared `symbol` elements, taken from the vscode-icons
extension artwork (MIT, pinned at `v12.13.0`). Copy the ones a page uses into a single
hidden `svg` at the top of the body, then reference them:

```html
<svg xmlns="http://www.w3.org/2000/svg" style="position:absolute;width:0;height:0;overflow:hidden" aria-hidden="true">
  <symbol id="vsi-rust" viewBox="0 0 32 32">...</symbol>
</svg>

<svg class="ic"><use href="#vsi-rust"/></svg>
```

Copy only what the page uses. A typical tree needs four to eight symbols, which costs one
to three KB. The whole file is 80 KB and does not belong in a page.

The sprite is the one asset that cannot be uploaded as a sibling file. Chrome and Safari
refuse to resolve `use href="sprite.svg#id"` across files, so the symbols have to be in
the same document as the `use`.

Use `position:absolute;width:0;height:0`, not `display:none`. A `display:none` sprite
stops `use` from resolving in some browsers.

### Names

| File | Symbol |
| --- | --- |
| `.rs` | `vsi-rust` |
| `Cargo.toml`, `Cargo.lock` | `vsi-cargo` |
| `.nix` | `vsi-nix` |
| `.ts` | `vsi-typescript` |
| `.d.ts` | `vsi-typescript-def` |
| `.test.ts`, `.spec.ts` | `vsi-testts` |
| `.tsx` | `vsi-tsx` |
| `.js`, `.mjs`, `.cjs` | `vsi-javascript` |
| `.jsx` | `vsi-jsx` |
| `tsconfig.json` | `vsi-tsconfig` |
| `package.json`, `package-lock.json` | `vsi-npm` |
| `pnpm-lock.yaml` | `vsi-pnpm` |
| `.json` | `vsi-json` |
| `.json5`, `.jsonc` | `vsi-json5` |
| `.py` | `vsi-python` |
| `.go` | `vsi-go` |
| `.sol` | `vsi-solidity` |
| `.sh`, `.bash`, `.zsh` | `vsi-shell` |
| `.sql` | `vsi-sql` |
| `.graphql`, `.gql` | `vsi-graphql` |
| `.vue` | `vsi-vue` |
| `.svelte` | `vsi-svelte` |
| `.toml` | `vsi-toml` |
| `.yaml`, `.yml` | `vsi-yaml` |
| `.xml` | `vsi-xml` |
| `.md` | `vsi-markdown` |
| `.txt` | `vsi-text` |
| `.html` | `vsi-html` |
| `.css` | `vsi-css` |
| `.scss`, `.sass` | `vsi-scss` |
| `.svg` | `vsi-svg` |
| `.png`, `.jpg`, `.webp`, `.gif` | `vsi-image` |
| `Dockerfile`, `.dockerfile` | `vsi-docker` |
| `.gitignore`, `.gitattributes` | `vsi-git` |
| anything else | `vsi-file` |

Folders: `vsi-folder`, `vsi-folder-open`, and by role `vsi-folder-src`,
`vsi-folder-test`, `vsi-folder-dist`, `vsi-folder-docs`, `vsi-folder-config`,
`vsi-folder-node`, `vsi-folder-git`, `vsi-folder-public`.

An extension not in this table gets `vsi-file`. Do not reach for the nearest plausible
logo; a wrong language on a file is worse than a generic page icon, because the reader
believes it.

### Adding a symbol

Fetch `https://cdn.jsdelivr.net/gh/vscode-icons/vscode-icons@v12.13.0/icons/<name>.svg`,
then do all four of these. Skipping any one of them fails silently, and a silently broken
icon renders as empty space, which looks exactly like an icon that has not loaded.

1. **Check the response is an SVG.** A missing icon returns a 404 body as plain text, and
   an unchecked fetch saves that text as if it were artwork. `file_type_lock` does not
   exist, for one.
2. **Confirm the name.** The icon file name is not always the language name.
   `Cargo.toml` is `file_type_cargo`, not `file_type_toml`. `package.json` is
   `file_type_npm`. The authoritative table is in the `vscode-icons-js` package, under
   `dist/generated/FileNamesToIcon.js` and `FileExtensions1ToIcon.js`.
3. **Rename every internal id, in all three forms.** Icons that use a gradient, a clip
   path, or a nested symbol keep it in their own `defs` under a one letter id, and several
   icons use the same letter. Rename `id="a"` to something unique, and rewrite both
   `href="#a"` and `url(#a)` to match. `file_type_rust` points at its gradient with
   `url()` and `file_type_cargo` points at its symbol with `href`, so handling only one
   form breaks the other icon.
4. **Verify.** Every `url(#x)` and every `href="#x"` in the finished file must have a
   matching `id="x"` in the same file, and no id may appear twice.

Strip the outer `svg` tag and the `title`, wrap the rest in
`<symbol id="vsi-name" viewBox="0 0 32 32">`.

### Theme

The sprite carries the standard artwork, which is legible on both page surfaces.
vscode-icons also ships `file_type_light_*` variants for a few near black icons. They are
not worth a theme swap for the handful they cover.

## Interface glyphs

Inline at write time, never load an icon library at runtime. Fetch the SVG from
`https://unpkg.com/lucide-static@1.31.0/icons/<name>.svg`, paste it inline, size it to the
text beside it with `width="1em" height="1em"`, and let it inherit colour through
`currentColor`.

Use them sparingly. A label beats an icon that needs explaining. File type icons in a tree
are the exception, and there one per row is the whole point.
