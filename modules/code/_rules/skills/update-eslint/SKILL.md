---
name: update-eslint
description: Use when updating eslint-plugin-v3xlabs and eslint to latest versions. Checks pnpm, installs, runs autofix, reviews diff, and corrects problematic auto-fix output.
---

# Update eslint-plugin-v3xlabs to Latest

## Steps

### 1. Check Current and Latest Versions

1. Read `package.json` devDependencies for `eslint` and `eslint-plugin-v3xlabs`.

   pnpm view eslint-plugin-v3xlabs version
   pnpm view eslint version
   pnpm view eslint-plugin-v3xlabs@latest peerDependencies

2. The plugin can set a minimum eslint peer version. If it needs a major version change (for example, eslint 10.x), you must update both together.

### 2. Update package.json

Edit `package.json`. Set the exact versions:

```json
"eslint": "<latest>",
"eslint-plugin-v3xlabs": "<latest>",
```

### 3. Install

Run:

   pnpm install

Verify the installed versions:

   pnpm ls eslint eslint-plugin-v3xlabs --depth=0

### 4. Run Autofix

Run:

   pnpm run lint:fix

### 5. Evaluate git diff

Run `git diff`. Group the changes into these categories:

| Category | What to look for | Verdict |
|---|---|---|
| Unicode to ASCII | `...` to `...`, `--` to `--`, `'` to `'`, `"` to `"` | Clean - accept |
| Boolean prefixes | `cancelled` to `isCancelled`, `valid` to `isValid`, `native` to `isNative`, and so on | Clean - accept |
| Abbreviation expansion | `i` to `index`, `val` to `value`, `params` to `parameters`, `el` to `element`, `ctx` to `context`, `src` to `source`, `obj` to `object` | Clean - accept |
| Idiomatic rewrites | `Object.keys(o).map(k => o[k])` to `Object.entries(o).map(([k,v]) => v)`, `...(x === undefined ? {} : {x})` to `...(x !== undefined && {x})` | Clean - accept |
| Props to Properties | Type names such as `DemoFrameProps` to `DemoFrameProperties` | Stylistic - verbose but harmless |
| Numeric separators removed | `0.000_62` to `0.00062` | Readability loss - optional revert |
| x to x | Close button symbols | UX regression - use x for buttons |

### 6. Fix Autofix Bugs

Two common autofix bugs to find:

**Bug A - Mangled HTML entity.** The no-llm-fingerprint rule sometimes removes the `&` from HTML entities. Look for:

   token'rsquo;s

Fix to: `token's`

Search the diff for `rsquo`, `amp`, `lt`, `gt` to find these.

**Bug B - Trailing underscore rename.** When abbreviation expansion creates a name collision (for example, `chainIdNum` to `chainIdNumber` clashes with a local that already exists), the autofixer adds `_` at the end. Look for:

   chainIdNumber_

Fix to: `getChainIdNumber`

Rename the definition and its call site.

### 7. Verify

Run:

   pnpm run lint

Make sure that the fixes did not add new errors.
