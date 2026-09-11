{
  zone,
  sections,
}: let
  card = svc: ''<li><a href="https://${svc.name}"><img src="/icons/${svc.icon}.webp" alt="" width="96" height="96"><strong>${svc.title}</strong><span>${svc.name}</span></a></li>'';

  block = section:
    builtins.concatStringsSep "\n" (
      ["<section>"]
      ++ (
        if section.title == null
        then []
        else ["<h2>${section.title}</h2>"]
      )
      ++ ["<ul>"]
      ++ map card section.services
      ++ ["</ul>" "</section>"]
    );

  layout = name: layoutSections: ''
    <main class="layout layout-${name}">
      <h1>${zone}</h1>
      ${builtins.concatStringsSep "\n      " (map block layoutSections)}
    </main>
  '';
in ''
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${zone}</title>
      <script>
          try {
              const layout = localStorage.getItem("v3x.home.layout");
              if (["current", "quiet", "grid", "daily"].includes(layout)) {
                  document.documentElement.dataset.layout = layout;
              }
          } catch {}
      </script>
      <style>
          :root { color-scheme: dark; }
          * { box-sizing: border-box; }
          html[data-layout="daily"] { color-scheme: light; }
          body {
              margin: 0;
              min-height: 100dvh;
              background: #000;
              color: #e6e6ea;
              font: 16px monospace;
          }
          html[data-layout="daily"] body {
              background: #f0eee7;
              color: #23221f;
          }
          .layouts {
              display: grid;
              min-height: 100dvh;
              padding: 3rem 1.5rem;
              place-content: center;
          }
          .layout { display: none; }
          html:not([data-layout]) .layout-current,
          html[data-layout="current"] .layout-current,
          html[data-layout="quiet"] .layout-quiet,
          html[data-layout="grid"] .layout-grid,
          html[data-layout="daily"] .layout-daily { display: grid; }
          .layout h1 { margin: 0; }
          .layout section { margin: 0; }
          .layout ul {
              margin: 0;
              padding: 0;
              list-style: none;
          }
          .layout a { color: inherit; text-decoration: none; }
          .layout a:focus-visible { outline: 2px solid #a8b8ff; outline-offset: 2px; }
          .layout img { object-fit: contain; }

          .layout-current { width: min(60rem, 90vw); gap: 2rem; }
          .layout-current h1 { font-size: 1rem; font-weight: 500; color: #6f6f7b; }
          .layout-current section { display: grid; gap: .6rem; }
          .layout-current h2 {
              margin: 0;
              font-size: 1rem;
              color: #55555f;
          }
          .layout-current ul {
              display: grid;
              grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr));
              gap: .5rem;
          }
          .layout-current a {
              display: grid;
              grid-template-columns: 2rem 1fr;
              align-items: center;
              gap: 0 .85rem;
              padding: .75rem 1rem;
              border: 1px solid #1e1e26;
              border-radius: .5rem;
          }
          .layout-current a:hover { border-color: #45454f; background: #0c0c10; }
          .layout-current img { grid-row: span 2; width: 2rem; height: 2rem; }
          .layout-current strong { font-weight: 600; }
          .layout-current span { color: #6f6f7b; font-size: 1rem; }

          .layout-quiet { width: min(72rem, 90vw); gap: clamp(2.5rem, 6vh, 5rem); }
          .layout-quiet h1 { font-size: 1rem; font-weight: 500; letter-spacing: -.02em; }
          .layout-quiet section { border-top: 1px solid #2b2d32; padding-top: .55rem; }
          .layout-quiet h2 {
              margin: 0 0 .9rem;
              color: #989ba2;
              font-size: .76rem;
              font-weight: 400;
              line-height: 1.3;
          }
          .layout-quiet ul {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(min(100%, 14rem), 1fr));
              gap: .15rem clamp(1rem, 2vw, 2rem);
          }
          .layout-quiet a {
              display: grid;
              grid-template-columns: 1.7rem minmax(0, 1fr);
              grid-template-areas: "icon title" "icon host";
              column-gap: .7rem;
              align-items: center;
              min-height: 3.7rem;
              padding: .35rem;
          }
          .layout-quiet a:hover { background: #202126; }
          .layout-quiet img { grid-area: icon; width: 1.7rem; height: 1.7rem; }
          .layout-quiet strong { grid-area: title; font-size: .88rem; font-weight: 400; }
          .layout-quiet span { grid-area: host; color: #83858c; font-size: .7rem; }

          .layout-grid { width: min(76rem, 90vw); gap: 0; }
          .layout-grid h1 {
              margin-bottom: 1.5rem;
              padding-bottom: 1.5rem;
              border-bottom: 1px solid #34363c;
              font-size: 1.15rem;
              font-weight: 500;
              letter-spacing: -.03em;
          }
          .layout-grid section {
              display: grid;
              grid-template-columns: minmax(7rem, 18%) minmax(0, 1fr);
              gap: 1rem 2rem;
              padding: 2rem 0;
              border-bottom: 1px solid #34363c;
          }
          .layout-grid h2 {
              margin: .2rem 0 0;
              color: #a9abb2;
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
              font-size: .84rem;
              font-weight: 400;
          }
          .layout-grid ul {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(min(100%, 9.5rem), 1fr));
              gap: .5rem;
          }
          .layout-grid a {
              display: grid;
              min-height: 8.75rem;
              align-content: space-between;
              gap: 1.2rem;
              padding: 1rem;
              background: #1e2025;
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
          }
          .layout-grid a:hover { background: #2b2e35; }
          .layout-grid img { width: 2.4rem; height: 2.4rem; }
          .layout-grid strong { font-size: .9rem; font-weight: 400; line-height: 1.25; }
          .layout-grid span { display: none; }

          .layout-daily {
              width: min(80rem, 90vw);
              grid-template-columns: repeat(4, minmax(0, 1fr));
              gap: 1px;
              background: #bdb8ac;
              color: #23221f;
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
          }
          .layout-daily h1 {
              grid-column: 1 / -1;
              padding: 0 0 2rem;
              background: #f0eee7;
              font-size: clamp(1.8rem, 4vw, 3rem);
              font-weight: 400;
              letter-spacing: -.04em;
          }
          .layout-daily section {
              min-height: 15rem;
              padding: 1rem;
              background: #f0eee7;
          }
          .layout-daily h2 {
              margin: 0 0 1.25rem;
              color: #6c675c;
              font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
              font-size: .72rem;
              font-weight: 400;
          }
          .layout-daily ul { display: grid; gap: .2rem; }
          .layout-daily a {
              display: grid;
              grid-template-columns: 1.65rem minmax(0, 1fr);
              align-items: center;
              gap: .65rem;
              min-height: 2.8rem;
              padding: .25rem;
          }
          .layout-daily a:hover { background: #e0dccf; }
          .layout-daily a:focus-visible { outline-color: #315f84; }
          .layout-daily img { width: 1.45rem; height: 1.45rem; }
          .layout-daily strong { font-size: .98rem; font-weight: 400; line-height: 1.15; }
          .layout-daily span { display: none; }

          .layout-switcher {
              position: fixed;
              top: .75rem;
              right: .75rem;
              z-index: 1;
              display: flex;
              gap: .25rem .65rem;
              align-items: center;
              margin: 0;
              padding: .55rem .7rem;
              border: 1px solid #34363c;
              background: #16181d;
              color: #c6c8cf;
              font: .72rem system-ui, -apple-system, "Segoe UI", sans-serif;
          }
          .layout-switcher legend { padding: 0 .25rem; color: #9699a2; }
          .layout-switcher label { display: flex; gap: .25rem; align-items: center; }
          .layout-switcher input { margin: 0; accent-color: #a8b8ff; }
          .layout-switcher label:has(input:focus-visible) { outline: 2px solid #a8b8ff; outline-offset: 2px; }
          html[data-layout="daily"] .layout-switcher {
              border-color: #bdb8ac;
              background: #f0eee7;
              color: #464239;
          }
          html[data-layout="daily"] .layout-switcher legend { color: #6c675c; }
          html[data-layout="daily"] .layout-switcher input { accent-color: #315f84; }
          html[data-layout="daily"] .layout-switcher label:has(input:focus-visible) { outline-color: #315f84; }

          @media (max-width: 44rem) {
              .layout-grid section { grid-template-columns: 1fr; gap: .75rem; padding: 1.5rem 0; }
              .layout-grid h2 { margin: 0; }
              .layout-daily { grid-template-columns: repeat(2, minmax(0, 1fr)); }
          }
          @media (max-width: 30rem) {
              .layouts { padding: 4.75rem 1rem 1rem; }
              .layout-current, .layout-quiet, .layout-grid, .layout-daily { width: 100%; }
              .layout-current ul { grid-template-columns: 1fr; }
              .layout-daily { grid-template-columns: 1fr; }
              .layout-switcher { left: .5rem; right: .5rem; justify-content: space-between; }
          }
      </style>
  </head>
  <body>
      <fieldset class="layout-switcher">
          <legend>Layout</legend>
          <label><input type="radio" name="layout" value="current" checked> Current</label>
          <label><input type="radio" name="layout" value="quiet"> Index</label>
          <label><input type="radio" name="layout" value="grid"> Grid</label>
          <label><input type="radio" name="layout" value="daily"> Directory</label>
      </fieldset>
      <div class="layouts">
        ${layout "current" sections}
        ${layout "quiet" sections}
        ${layout "grid" sections}
        ${layout "daily" sections}
      </div>
      <script>
          const key = "v3x.home.layout";
          const current = document.documentElement.dataset.layout || "current";
          const inputs = document.querySelectorAll('input[name="layout"]');

          inputs.forEach((input) => {
              input.checked = input.value === current;
              input.addEventListener("change", () => {
                  document.documentElement.dataset.layout = input.value;
                  try {
                      localStorage.setItem(key, input.value);
                  } catch {}
              });
          });
      </script>
  </body>
  </html>
''
