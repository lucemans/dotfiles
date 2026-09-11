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
              if (["current", "grid", "daily"].includes(layout)) {
                  document.documentElement.dataset.layout = layout;
              }
          } catch {}
      </script>
      <link rel="stylesheet" href="/home.css">
  </head>
  <body>
      <nav class="layout-switcher" aria-label="Layout">
          <button type="button" data-layout="current" aria-label="Use current layout" aria-pressed="true" title="Current layout">
              <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect></svg>
          </button>
          <button type="button" data-layout="grid" aria-label="Use grid layout" aria-pressed="false" title="Grid layout">
              <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="4" height="4"></rect><rect x="10" y="3" width="4" height="4"></rect><rect x="17" y="3" width="4" height="4"></rect><rect x="3" y="10" width="4" height="4"></rect><rect x="10" y="10" width="4" height="4"></rect><rect x="17" y="10" width="4" height="4"></rect><rect x="3" y="17" width="4" height="4"></rect><rect x="10" y="17" width="4" height="4"></rect><rect x="17" y="17" width="4" height="4"></rect></svg>
          </button>
          <button type="button" data-layout="daily" aria-label="Use directory layout" aria-pressed="false" title="Directory layout">
              <svg viewBox="0 0 24 24" aria-hidden="true"><line x1="4" y1="5" x2="20" y2="5"></line><line x1="4" y1="12" x2="20" y2="12"></line><line x1="4" y1="19" x2="20" y2="19"></line></svg>
          </button>
      </nav>
      <div class="layouts">
        ${layout "current" sections}
        ${layout "grid" sections}
        ${layout "daily" sections}
      </div>
      <script>
          const current = document.documentElement.dataset.layout || "current";
          const buttons = document.querySelectorAll("button[data-layout]");

          buttons.forEach((button) => {
              button.setAttribute("aria-pressed", String(button.dataset.layout === current));
              button.addEventListener("click", () => {
                  const layout = button.dataset.layout;
                  document.documentElement.dataset.layout = layout;
                  buttons.forEach((other) => {
                      other.setAttribute("aria-pressed", String(other === button));
                  });
                  try {
                      localStorage.setItem("v3x.home.layout", layout);
                  } catch {}
              });
          });
      </script>
  </body>
  </html>
''
