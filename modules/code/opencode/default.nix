{inputs, ...}: {
  flake.nixosModules.opencode = {
    self,
    pkgs,
    ...
  }: let
    rules = import ../_rules;
    opencodeConfig =
      (builtins.fromJSON (builtins.readFile ./opencode.jsonc))
      // {
        mcp = self.mcp.opencode;
      };
    opencode = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.opencode;
      runtimeInputs = with pkgs; [
        lua-language-server
        marksman
        mdx-language-server
        taplo
        typescript-language-server
        vscode-langservers-extracted
        yaml-language-server
      ];
    };
  in {
    environment.systemPackages = [opencode];

    environment.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.file =
      (rules.mkSkillFiles ".config/opencode/skills")
      // {
        ".config/opencode/opencode.jsonc" = {
          text = builtins.toJSON opencodeConfig;
          force = true;
        };

        ".config/opencode/AGENTS.md" = {
          source = rules.policy;
          force = true;
        };

        ".config/opencode/agents/visual-qa.md" = {
          source = ./agents/visual-qa.md;
          force = true;
        };
      };
  };
}
