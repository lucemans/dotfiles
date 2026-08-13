let
  skillEntries = builtins.readDir ./skills;
  skillNames =
    builtins.filter
    (name: skillEntries.${name} == "directory")
    (builtins.attrNames skillEntries);
in {
  policy = ./AGENTS.md;

  mkSkillFiles = skillDirectory:
    builtins.listToAttrs (builtins.map (skillName: {
        name = "${skillDirectory}/${skillName}";
        value = {
          source = ./skills + "/${skillName}";
          force = true;
        };
      })
      skillNames);
}
