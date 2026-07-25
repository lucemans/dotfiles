let
  skills = {
    typescript = ./skills/typescript/skill.md;
    update-eslint = ./skills/typescript/update-eslint.md;
    "solid-js" = ./skills/solid-js/skill.md;
    "web-design" = ./skills/web-design/skill.md;
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
