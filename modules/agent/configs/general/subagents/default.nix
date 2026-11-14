let
  preferences = import ../../model-preferences.nix;

  subagents = {
    comment-sicko = {
      description = "A deranged comment-hater that savors deletion and condemns workaround code.";
      claude = {
        tools = "Read, Edit, Bash";
        model = "haiku";
      };
      omp = {
        tools = "read, edit, bash";
        model = preferences.anthropic_haiku;
        thinkingLevel = "low";
      };
      opencode = {
        mode = "subagent";
        permission = {
          edit = "allow";
          bash = "ask";
        };
      };
    };
  };

  yamlValue = indent: value:
    if builtins.isAttrs value
    then "\n" + yamlBlock "${indent}  " value
    else " ${builtins.toJSON value}";

  yamlBlock = indent: attrs:
    builtins.concatStringsSep "\n"
    (builtins.map
      (key: "${indent}${key}:${yamlValue indent attrs.${key}}")
      (builtins.attrNames attrs));

  file = harness: name: let
    subagent = subagents.${name};
    identity =
      if harness == "claude" || harness == "omp"
      then {inherit name;}
      else {};
    frontmatter =
      identity
      // {inherit (subagent) description;}
      // subagent.${harness};
  in ''
    ---
    ${yamlBlock "" frontmatter}
    ---

    ${builtins.readFile (./. + "/${name}.md")}'';
in {
  files = harness: directory:
    builtins.listToAttrs (builtins.map (name: {
        name = "${directory}/${name}.md";
        value = {
          text = file harness name;
          force = true;
        };
      })
      (builtins.attrNames subagents));
}
