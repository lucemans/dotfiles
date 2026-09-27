let
  # Each subagent's prose lives in ./<name>.md without frontmatter. Claude Code
  # and OpenCode disagree on the frontmatter schema, so the shared fields sit
  # here and the per-harness attrset supplies the rest.
  subagents = {
    comment-sicko = {
      description = "A deranged comment-hater that savors deletion and condemns workaround code.";
      claude = {
        tools = "Read, Grep, Glob, Edit, Bash";
        model = "opus";
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

  # builtins.toJSON renders strings, numbers, booleans, and lists as valid YAML
  # scalars and flow sequences, so only nested attribute sets need a block.
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
      if harness == "claude"
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
  # Home files that install every subagent, in `harness`'s frontmatter, under
  # `directory`.
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
