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
    lib,
    pkgs,
    config,
    ...
  }: let
    opencodeConfig =
      (builtins.fromJSON (builtins.readFile ./opencode.jsonc))
      // {
        provider = config.inference.providers;
      };
    mcpServers =
      lib.mapAttrs (
        _: s:
          (
            if s ? url
            then
              {
                type = "remote";
                inherit (s) url;
              }
              // lib.optionalAttrs (s ? bearer) {
                headers.Authorization = "Bearer {file:${s.bearer}}";
              }
            else {
              type = "local";
              command = [s.command];
            }
          )
          // {enabled = true;}
          // lib.optionalAttrs (s.timeout != null) {inherit (s) timeout;}
      )
      config.agentRuntime.servers;
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
      ((import ../../skills).files ".config/opencode/skills")
      // ((import ../../subagents).files "opencode" ".config/opencode/agents")
      // {
        ".config/opencode/opencode.jsonc" = {
          text = builtins.toJSON (opencodeConfig
            // {
              mcp = lib.getAttrs config.agentRuntime.toolsets.base.servers mcpServers;
            });
          force = true;
        };

        ".config/opencode/AGENTS.md" = {
          source = ../../AGENTS.md;
          force = true;
        };
      };

    agentRuntime.harnesses.opencode = {
      command = ["opencode"];
      glyph = "";
      color = "248;248;242";
      blurb = "OpenCode";
      logo = ../../icons/opencode.png;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      # The sandbox points OPENCODE_CONFIG here, and OpenCode merges it over the
      # global config, whose servers are only base.
      mcp = {
        path = "/etc/agent/opencode.json";
        key = "mcp";
        servers = mcpServers;
      };
    };
  };
}
