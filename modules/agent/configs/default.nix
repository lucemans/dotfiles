let
  # Who gets which groups. A group is a directory next to this file with an
  # optional SYSTEM.md and skills/. Groups are listed lowest precedence first:
  # a later group replaces a skill of the same name.
  targets = {
    # The `agent` runtime on the desktop.
    runtime = ["general" "local"];

    # Kettle Code chats. `all` reaches every chat; the others add to it for
    # one kind of chat.
    kettle = {
      all = ["general" "extended"];
      chat = [];
      coordinator = ["coordinator"];
      butler = ["butler"];
    };
  };

  kettleGroups = role: targets.kettle.all ++ targets.kettle.${role};

  skillsIn = group: let
    dir = ./. + "/${group}/skills";
    entries = builtins.readDir dir;
    names = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
  in
    if builtins.pathExists dir
    then builtins.listToAttrs (map (name: {inherit name; value = dir + "/${name}";}) names)
    else {};

  # Skill name to its directory.
  skillsOf = groups: builtins.foldl' (found: group: found // skillsIn group) {} groups;

  promptFilesOf = groups:
    builtins.filter
    (file: builtins.pathExists file && builtins.readFile file != "")
    (map (group: ./. + "/${group}/SYSTEM.md") groups);

  # The groups' SYSTEM.md files as one file, in group order.
  promptOf = pkgs: groups:
    pkgs.writeText "SYSTEM.md"
    (builtins.concatStringsSep "\n" (map builtins.readFile (promptFilesOf groups)));

  # Home files that give one harness the skills, subagents and system prompt of
  # `groups`, at the paths that harness reads. Subagents are not grouped yet.
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
    }) (skillsOf groups)))
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
