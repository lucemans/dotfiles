{
  zone,
  sections,
}: let
  card = svc: ''<li><a href="https://${svc.name}"><img src="/icons/${svc.icon}.webp" alt="" width="96" height="96"><strong>${svc.title}</strong><span>${svc.name}</span></a></li>'';

  # Leading whitespace is absolute here, because the first line takes its
  # indentation from the interpolation site in the document below.
  block = section:
    builtins.concatStringsSep "\n" (
      ["<section>"]
      ++ (
        if section.title == null
        then []
        else ["        <h2>${section.title}</h2>"]
      )
      ++ ["        <ul>"]
      ++ map (svc: "          ${card svc}") section.services
      ++ ["        </ul>" "      </section>"]
    );
in ''
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${zone}</title>
      <style>
          :root { color-scheme: dark; }
          body {
              box-sizing: border-box;
              margin: 0;
              min-height: 100dvh;
              padding: 3rem 1.5rem;
              display: grid;
              place-content: center;
              background: #000;
              color: #e6e6ea;
              font: 16px monospace;
          }
          main { display: grid; gap: 2rem; width: min(60rem, 90vw); }
          h1 { margin: 0; font-size: 1rem; font-weight: 500; color: #6f6f7b; }
          section { display: grid; gap: .6rem; }
          h2 {
              margin: 0;
              font-size: 1rem;
              color: #55555f;
          }
          ul {
              margin: 0;
              padding: 0;
              list-style: none;
              display: grid;
              grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr));
              gap: .5rem;
          }
          a {
              display: grid;
              grid-template-columns: 2rem 1fr;
              align-items: center;
              gap: 0 .85rem;
              padding: .75rem 1rem;
              border: 1px solid #1e1e26;
              border-radius: .5rem;
              color: inherit;
              text-decoration: none;
          }
          a:hover { border-color: #45454f; background: #0c0c10; }
          img { grid-row: span 2; width: 2rem; height: 2rem; }
          strong { font-weight: 600; }
          span { color: #6f6f7b; font-size: 1rem; }
      </style>
  </head>
  <body>
      <main>
        <h1>${zone}</h1>
        ${builtins.concatStringsSep "\n      " (map block sections)}
      </main>
  </body>
  </html>
''
