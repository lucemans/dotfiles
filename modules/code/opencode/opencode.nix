{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.opencode = inputs.wrappers.lib.wrapPackage {
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
  };

  flake.nixosModules.opencode = {
    self,
    pkgs,
    config,
    ...
  }: let
    rules = import ../_rules;
    opencodeConfig =
      (builtins.fromJSON (builtins.readFile ./opencode.jsonc))
      // {
        mcp = self.mcp.opencode;
        provider = config.inference.providers;
      };
  in {
    imports = [
      self.nixosModules.inference
    ];

    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.opencode
      # opencode2
      # opencode2Update
    ];

    environment.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.file =
      (rules.mkSkillFiles ".config/opencode/skills")
      // (rules.mkAgentFiles "opencode" ".config/opencode/agents")
      // {
        ".config/opencode/opencode.jsonc" = {
          text = builtins.toJSON opencodeConfig;
          force = true;
        };

        ".config/opencode/AGENTS.md" = {
          source = rules.policy;
          force = true;
        };
      };
  };
}
