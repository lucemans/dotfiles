let
  skills = {
    typescript = ./skills/typescript/SKILL.md;
    "solid-js" = ./skills/solid-js/SKILL.md;
  };
in {
  policy = ./AGENTS.md;
  inherit skills;

  mkSkillFiles = skillDirectory:
    builtins.listToAttrs (builtins.map (skillName: {
      name = "${skillDirectory}/${skillName}/SKILL.md";
      value = {
        source = skills.${skillName};
        force = true;
      };
    }) (builtins.attrNames skills));
}
