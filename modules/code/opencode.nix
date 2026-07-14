{
  flake.nixosModules.opencode = {
    self,
    pkgs,
    ...
  }: let
    opencodeConfig =
      (builtins.fromJSON (builtins.readFile ./opencode/opencode.jsonc))
      // {
        mcp = self.mcp.opencode;
      };
  in {
    environment.systemPackages = [pkgs.opencode];

    environment.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.file.".config/opencode/opencode.jsonc" = {
      text = builtins.toJSON opencodeConfig;
      force = true;
    };

    home-manager.users.luc.home.file.".config/opencode/AGENTS.md" = {
      source = ./opencode/rules/AGENTS.md;
      force = true;
    };

    home-manager.users.luc.home.file.".config/opencode/rules/TYPESCRIPT.md" = {
      source = ./opencode/rules/TYPESCRIPT.md;
      force = true;
    };

    home-manager.users.luc.home.file.".config/opencode/agents/visual-qa.md" = {
      source = ./opencode/agents/visual-qa.md;
      force = true;
    };
  };
}
