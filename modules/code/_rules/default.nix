let
  skillEntries = builtins.readDir ./skills;
  skillNames =
    builtins.filter
    (name: skillEntries.${name} == "directory")
    (builtins.attrNames skillEntries);

  # Each agent's prose lives in ./agents/<name>.md without frontmatter. Claude
  # Code and OpenCode disagree on the frontmatter schema, so the shared fields
  # sit here and the per-harness attrset supplies the rest.
  agents = {
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

    visual-qa = {
      description = "Uses Playwright to inspect running frontend features, navigate the browser, capture screenshots, and review visual design quality. Read-only on source code.";
      claude = {};
      opencode = {
        mode = "subagent";
        model = "openai/gpt-5.6-terra";
        permission = {
          edit = "deny";
          bash = "ask";
          "playwright_*" = "allow";
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

  agentFile = harness: agentName: let
    agent = agents.${agentName};
    identity =
      if harness == "claude"
      then {name = agentName;}
      else {};
    frontmatter =
      identity
      // {inherit (agent) description;}
      // agent.${harness};
  in ''
    ---
    ${yamlBlock "" frontmatter}
    ---

    ${builtins.readFile (./agents + "/${agentName}.md")}'';
in {
  policy = ./AGENTS.md;

  mkSkillFiles = skillDirectory:
    builtins.listToAttrs (builtins.map (skillName: {
        name = "${skillDirectory}/${skillName}";
        value = {
          source = ./skills + "/${skillName}";
          recursive = true;
          force = true;
        };
      })
      skillNames);

  mkAgentFiles = harness: agentDirectory:
    builtins.listToAttrs (builtins.map (agentName: {
        name = "${agentDirectory}/${agentName}.md";
        value = {
          text = agentFile harness agentName;
          force = true;
        };
      })
      (builtins.attrNames agents));
}
