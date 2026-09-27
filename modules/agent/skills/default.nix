let
  entries = builtins.readDir ./.;
  names =
    builtins.filter
    (name: entries.${name} == "directory")
    (builtins.attrNames entries);
in {
  # Home files that install every skill directory under `directory`.
  files = directory:
    builtins.listToAttrs (builtins.map (name: {
        name = "${directory}/${name}";
        value = {
          source = ./. + "/${name}";
          recursive = true;
          force = true;
        };
      })
      names);
}
