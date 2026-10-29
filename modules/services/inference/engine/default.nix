{
  lib,
  pkgs,
}: {
  cpuFlags,
  flashAttnQuants,
  fetch,
  dir ? "/var/lib/llama-models",
}: models: let
  llama-cpp = import ./llama-cpp.nix {inherit lib pkgs;} {inherit cpuFlags flashAttnQuants;};

  inheritFrom = weights: src: lib.optionalAttrs (weights ? repo) {inherit (weights) repo rev;} // src;
  fileArgsOf = m: lib.mapAttrs (_: inheritFrom m.weights) (m.fileArgs or {});
  sourcesOf = m: [m.weights] ++ lib.attrValues (fileArgsOf m);

  filesOf = src:
    lib.mapAttrsToList (file: sha256: {
      inherit (src) repo rev;
      inherit file sha256;
      gated = src.gated or false;
      dest = "${dir}/${lib.replaceStrings ["/"] ["--"] src.repo}/${file}";
    }) (src.files or {});

  download = f:
    pkgs.fetchurl {
      url = "https://huggingface.co/${f.repo}/resolve/${f.rev}/${f.file}";
      inherit (f) sha256;
    };

  # The path of the first file of a source.
  pathOf = src:
    src.path or (let
      files = filesOf src;
      first = lib.head files;
    in
      if fetch == "runtime"
      then first.dest
      else if lib.length files == 1
      then "${download first}"
      else "${pkgs.linkFarm (lib.replaceStrings ["/"] ["-"] src.repo) (map (f: {
          name = f.file;
          path = download f;
        })
        files)}/${first.file}");

  entry = name: m: let
    alias =
      m.alias or name;
    cmd = lib.concatStringsSep " " (
      [llama-cpp.builds.${m.llama-cpp or llama-cpp.default}.server "--port" "\${PORT}" "--model" (pathOf m.weights)]
      ++ lib.optionals (alias != null) ["--alias" alias]
      ++ lib.concatLists (lib.mapAttrsToList (flag: src: [flag (pathOf src)]) (fileArgsOf m))
      ++ m.args or []
    );
  in
    removeAttrs m ["weights" "fileArgs" "args" "llama-cpp" "alias" "litellm"] // {inherit cmd;};
in {
  swap = lib.mapAttrs entry models;
  files = lib.unique (lib.concatMap (m: lib.concatMap filesOf (sourcesOf m)) (lib.attrValues models));
}
