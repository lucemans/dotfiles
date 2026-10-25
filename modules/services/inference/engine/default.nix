# Turns the model chunks of one machine into llama-swap entries and the list of files to fetch.
#
# A chunk is one model. Adding a model means adding a chunk next to the others in the machine's
# file under `models/`, and nothing else:
#
#   "gpt-oss-20b" = {
#     llama-cpp = "v0.7.0";          # a build from llama-cpp.nix, `default` when left out
#     weights = {                    # the file llama-server gets as --model
#       repo = "unsloth/gpt-oss-20b-GGUF";
#       rev = "d449b42d…";           # an exact commit
#       files."gpt-oss-20b-F16.gguf" = "<sha256>";
#     };
#     fileArgs."--spec-draft-model".files."draft.gguf" = "<sha256>";   # other files, by flag
#     args = ["--ctx-size 8192" "--flash-attn on"];                    # the rest of the command line
#     ttl = 900;                     # any other key goes to the llama-swap entry as it is
#   };
#
# - `files` maps a file name to its sha256. A model in several parts lists all of them: the first
#   by name is passed, and llama.cpp finds the others next to it.
# - A `fileArgs` source uses the repo and commit of `weights` unless it names its own.
# - `gated = true` on a source marks a repo that needs a login, so it has to be placed by hand.
# - `weights.path` points at a file that is placed by hand and not verified.
# - The command line starts with --model and --alias, the alias being the key. `alias = null`
#   leaves it out.
#
# `fetch` is how the files arrive. "runtime" downloads them after boot into `dir`, outside the
# Nix store, so neither a boot nor a deploy waits for them. "store" fetches them at build time.
#
# Returns `{ swap, files }`: the llama-swap `models` and the files for `model-fetch.nix`.
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
    removeAttrs m ["weights" "fileArgs" "args" "llama-cpp" "alias"] // {inherit cmd;};
in {
  swap = lib.mapAttrs entry models;
  files = lib.unique (lib.concatMap (m: lib.concatMap filesOf (sourcesOf m)) (lib.attrValues models));
}
