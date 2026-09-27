# Interactive content

The page is served in a sandbox with an opaque origin. Scripts run; cookies and
credentialed requests do not exist. Interactivity is welcome when it serves the reading,
never as decoration.

**Pin every import exactly.** Revisions are permanent, so an unpinned import changes how
an old revision renders later. That is a bug, not a convenience.

## Scripts

Small inline vanilla JavaScript is fine: sorting a table, filtering a list, toggling
between two views of the same data. No frameworks. Solid and React need a build step and
do not belong in a document.

The page must read fully with scripts disabled or esm.sh unreachable. Script-driven
content decorates markup that is already there.

## Charts

TanStack Charts through esm.sh, exact pinned version, framework-free host.

```
<div id="chart"><p>Interactive chart. The data is in the table below.</p></div>
<script type="module">
import { defineChart, lineY, barY, mountChart }
  from "https://esm.sh/@tanstack/charts@0.11.2";
import { scaleLinear } from "https://esm.sh/@tanstack/charts@0.11.2/scales/linear";
import { scaleBand } from "https://esm.sh/@tanstack/charts@0.11.2/scales/band";

const element = document.querySelector("#chart");
element.replaceChildren();
mountChart(element, { definition, height: 300, ariaLabel: "..." });
</script>
```

- The container keeps fallback text until the mount succeeds.
- Every chart also ships its data as a table in the page.
- Pick series color per theme with `matchMedia("(prefers-color-scheme: dark)")` and keep
  it clearly readable on both surfaces. One hue per series, fixed assignment, never a
  rainbow. This is the color rule from SKILL.md section 4: a hue means one series.
- A chart spans the full content width like everything else. Set `width: 100%` and a fixed `height`, and let it grow with the window.

## Icons

See `icons.md`. Both the file type sprite and the inline interface glyphs live there.
