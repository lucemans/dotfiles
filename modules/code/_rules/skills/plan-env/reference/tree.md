# File trees

A tree answers one question: which files does this touch, and how. Reach for it when a
change spans more than three files, when the reader asks about blast radius, or when the
shape of a directory is the thing being explained.

`.tree` is in `document.css`, so it is available on every page with no extra file to
inline. File icons come from `reference/icons.svg`. Read `icons.md` before you copy any.

## Never draw the lines

Write nesting. Write a status class. That is all. The brackets, the indent, and the status
marker are drawn by CSS from one measurement, `--icon-c`, which is the centre of the icon
column. A child list is indented by exactly that, so a bracket always hangs from its own
parent folder's icon.

Box drawing characters in a `pre` are the failure this component exists to remove. Getting
them right means tracking, per line, which ancestors still have siblings below. That goes
wrong from the third level down, and a wrong tree reads as broken rather than as a tree.

## Markup

```html
<div class="tree">
  <p class="root"><svg class="ic"><use href="#vsi-folder-src"/></svg><span class="nm">crates/relay-node</span></p>
  <ul>
    <li class="dir"><span class="row"><svg class="ic"><use href="#vsi-folder"/></svg><span class="nm">src</span></span>
      <ul>
        <li><span class="row add"><svg class="ic"><use href="#vsi-rust"/></svg><span class="nm">retry.rs</span><span class="note">+120</span></span></li>
        <li><span class="row del"><svg class="ic"><use href="#vsi-rust"/></svg><span class="nm">legacy_pool.rs</span><span class="note">&#8722;96</span></span></li>
        <li><span class="row"><svg class="ic"><use href="#vsi-rust"/></svg><span class="nm">main.rs</span></span></li>
      </ul>
    </li>
    <li><span class="row mod"><svg class="ic"><use href="#vsi-cargo"/></svg><span class="nm">Cargo.toml</span><span class="note">+3 &#8722;1</span></span></li>
    <li><span class="row rest"><span class="nm">6 unchanged files</span></span></li>
  </ul>
</div>
```

A row is always four things in this order: status, icon, name, note. A directory row is
the same, followed by its `ul` inside the same `li`.

## The root is a caption

`p.root` carries the path the tree hangs from. It is not a node, and it has no `li`.

This matters more than it looks. A tree wrapped in a single root node draws a vertical
line for that root and another for its first real directory, a few pixels apart, saying
nothing different. Two parallel lines read as noise. Put the root in the caption and the
tree draws one line per directory that actually groups siblings.

## Statuses

| Class on `.row` | Means | Hue |
| --- | --- | --- |
| `add` | The change creates this file | `--pos` |
| `del` | The change removes it. The name is struck through | `--neg` |
| `mod` | The change edits it in place | `--accent` |
| `move` | Renamed or moved. Name the source in a `.was` span | `--move` |
| none | Untouched, shown so the reader can locate the change | `--guide` |
| `rest` | A counted line for siblings not shown | `--ink-faint` |

The band, the bracket, and the name all take the status hue. These are the same six hues
the rest of the page uses, so green means added here and added everywhere.

Name the binding once, with a `.legend` above the first tree:

```html
<p class="legend">
  <span class="add"><i></i> added</span>
  <span class="del"><i></i> removed</span>
  <span class="mod"><i></i> modified</span>
  <span class="move"><i></i> renamed or moved</span>
  <span><i style="background:none"></i> untouched, shown to locate the change</span>
</p>
```

A rename shows the destination in `.nm` and the source beside it, on one line, so the
reader never hunts for the other end of the move:

```html
<span class="nm">icons.md <span class="was">&#8592; interactive.md</span></span>
```

A renamed directory says so on its own row, and its children carry `move` too.

## Ordering

Directories first, then files. Alphabetical inside each group. This is not a preference,
it is the order every file explorer uses, and a model left to itself sorts by whichever
order it happened to think of the paths in.

## What to leave out

A tree is not an inventory. Show the paths the work touches, plus the parents needed to
locate them, and account for everything else with one `rest` line stating how many
siblings are untouched.

That line is a count, not an ellipsis. The rule against eliding material still holds: the
material of a change tree is the changed files, and an untouched sibling is not part of
it. `and so on`, `...`, and a truncated list are still wrong.

## The note column

`.note` sits at the right edge of the block, aligned across every depth. Put a line delta
there, or a short fact. Never put a number in it that the work did not produce.

## The note gutter

Use it. On a change tree the gutter is the default, not an extra.

The path says which file. The line delta says how much. Neither says why, and why is the
one thing the reader cannot reconstruct from the repository. A tree without the gutter
makes the reader ask you a question the tree could have answered.

Leave it off in two cases: the tree is showing structure rather than a change, so there is
nothing to say per row, or the tree has to sit in a narrow column. It needs the full
content width.

Add `gutter` to the tree and a `.say` span to each row:

```html
<div class="tree gutter">
  ...
  <li><span class="row add"><svg class="ic"><use href="#vsi-rust"/></svg><span class="nm">retry.rs</span><span class="note">+120</span><span class="say">exponential backoff with jitter</span></span></li>
```

The line delta stays right aligned against the hairline. Everything past it is prose.

One short clause per row, and a real one. "updated" and "changes" are not reasons. Name
what the edit does: `send() goes through the retry loop`, `icon guidance leaves for
icons.md`, `import paths follow the rename`. A row you cannot write a reason for is
probably a row that belongs in the counted `rest` line.

## Sizing

The five values at the top of `.tree` in `document.css` drive everything: `--fs`,
`--row-h`, `--icon-w`, `--col-gap`, `--step`. Override those on the tree to change its
size, and the brackets follow. Never hand pick an indent, a bracket offset, or a marker
position; that is exactly the drift this design removes.
