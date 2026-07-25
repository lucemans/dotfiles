---
name: update-eslint-v3xlabs
description: Use when updating eslint-plugin-v3xlabs and eslint to latest versions. Checks pnpm, installs, runs autofix, reviews diff, and corrects problematic auto-fix output.
---

# Update eslint-plugin-v3xlabs to latest

## Steps

### 1. Check current and latest versions

Read `package.json` devDependencies for `eslint` and `eslint-plugin-v3xlabs`.

pnpm view eslint-plugin-v3xlabs version
pnpm view eslint version
pnpm view eslint-plugin-v3xlabs@latest peerDependencies

The plugin may pin a minimum eslint peer version. If it requires a major bump (e.g. eslint 10.x), both must be updated together.

### 2. Update package.json

Edit `package.json` to set exact versions:

```json
"eslint": "<latest>",
"eslint-plugin-v3xlabs": "<latest>",
3. Install
pnpm install
Verify installed versions with pnpm ls eslint eslint-plugin-v3xlabs --depth=0.
4. Run autofix
pnpm run lint:fix
5. Evaluate git diff
Run git diff and categorize changes:
Category	What to look for	Verdict
Unicode → ASCII	… → ..., — → --, ' → ', " → "	Clean — accept
Boolean prefixes	cancelled → isCancelled, valid → isValid, native → isNative, etc.	Clean — accept
Abbreviation expansion	i → index, val → value, params → parameters, el → element, ctx → context, src → source, obj → object	Clean — accept
Idiomatic rewrites	Object.keys(o).map(k => o[k]) → Object.entries(o).map(([k,v]) => v), ...(x === undefined ? {} : {x}) → ...(x !== undefined && {x})	Clean — accept
Props → Properties	Type names like DemoFrameProps → DemoFrameProperties	Stylistic — verbose but harmless
Numeric separators removed	0.000_62 → 0.00062	Readability loss — optional revert
× → x	Close button symbols	UX regression — prefer × for buttons
6. Fix autofix bugs
Two common autofix bugs to catch:
Bug A — Mangled HTML entity. The no-llm-fingerprint rule sometimes chops & off HTML entities. Look for:
token'rsquo;s   →   fix to: token's
Search the diff for rsquo, amp, lt, gt to catch these.
Bug B — Trailing underscore rename. When abbreviation expansion creates a name collision (e.g. chainIdNum → chainIdNumber clashes with an existing local), the autofixer appends _. Look for:
chainIdNumber_   →   fix to: getChainIdNumber
Rename both the definition and its call site.
7. Verify
Run pnpm run lint to confirm no new errors were introduced by the fixes.
