let
  targets = {
    runtime = ["general" "local"];

    kettle = {
      all = ["general" "extended"];
      chat = [];
      coordinator = ["coordinator"];
      butler = ["butler"];
      triage = ["triage"];
    };
  };

  kettleGroups = role: targets.kettle.all ++ targets.kettle.${role};

  preferences = import ./model-preferences.nix;

  skillsIn = pkgs: group: let
    dir = ./. + "/${group}/skills";
    entries = builtins.readDir dir;
    names = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
  in
    if builtins.pathExists dir
    then
      builtins.listToAttrs (map (name: {
          inherit name;
          value =
            if group == "extended" && name == "00-model-preferences"
            then let
              rendered =
                builtins.replaceStrings
                (map (key: "{${key}}") (builtins.attrNames preferences))
                (builtins.attrValues preferences)
                (builtins.readFile (dir + "/${name}/SKILL.md"));
            in
              assert builtins.length (builtins.split "[{][a-z_]+[}]" rendered) == 1;
                pkgs.linkFarm name [
                  {
                    name = "SKILL.md";
                    path = pkgs.writeText "SKILL.md" rendered;
                  }
                ]
            else dir + "/${name}";
        })
        names)
    else {};

  skillsOf = pkgs: groups: builtins.foldl' (found: group: found // skillsIn pkgs group) {} groups;

  promptFilesOf = groups:
    builtins.filter
    (file: builtins.pathExists file && builtins.readFile file != "")
    (map (group: ./. + "/${group}/SYSTEM.md") groups);

  promptOf = pkgs: groups:
    pkgs.writeText "SYSTEM.md"
    (builtins.concatStringsSep "\n" (map builtins.readFile (promptFilesOf groups)));

  homeFiles = pkgs: groups: {
    harness,
    skillsDir,
    agentsDir,
    promptFile,
  }:
    builtins.listToAttrs (builtins.attrValues (builtins.mapAttrs (name: source: {
      name = "${skillsDir}/${name}";
      value = {
        inherit source;
        recursive = true;
        force = true;
      };
    }) (skillsOf pkgs groups)))
    // (import ./general/subagents).files harness agentsDir
    // {
      ${promptFile} = {
        source = promptOf pkgs groups;
        force = true;
      };
    };
in {
  inherit targets kettleGroups skillsOf promptOf homeFiles;
}
