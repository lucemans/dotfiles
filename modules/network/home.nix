{
  zone,
  services,
}: let
  entry = svc: ''
    <li><a href="https://${svc.name}"><strong>${svc.title}</strong><span>${svc.name}</span></a></li>'';

  listed = builtins.sort (a: b: a.title < b.title) (builtins.attrValues services);
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
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-content: center;
              gap: 2rem;
              background: #101014;
              color: #e6e6ea;
              font: 15px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
          }
          h1 { margin: 0; font-size: 1rem; font-weight: 500; color: #6f6f7b; }
          ul { margin: 0; padding: 0; list-style: none; display: grid; gap: .5rem; }
          a {
              display: grid;
              gap: .15rem;
              padding: .75rem 1rem;
              min-width: 18rem;
              border: 1px solid #26262e;
              border-radius: .5rem;
              color: inherit;
              text-decoration: none;
          }
          a:hover { border-color: #4a4a58; background: #16161c; }
          span { color: #6f6f7b; font-size: .85rem; }
      </style>
  </head>
  <body>
      <h1>${zone}</h1>
      <ul>
        ${builtins.concatStringsSep "\n      " (map entry listed)}
      </ul>
  </body>
  </html>
''
