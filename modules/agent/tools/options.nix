{
  inputs,
  lib,
  config,
  ...
}: let
  servers = lib.mapAttrs (_: s: {timeout = 30000;} // s) config.agentRuntime.servers;
  local = lib.filterAttrs (_: s: s ? command) servers;
  bearers = lib.filterAttrs (_: s: s ? bearer) servers;
in {
  # One definition per server, in no harness's vocabulary. A local server names
  # its `command`, and its package is the one of that name in the `from` flake,
  # this flake unless set. A remote server has a `url` instead, and `bearer`
  # names the sops secret that holds its token. `timeout` is in milliseconds,
  # 30000 unless set, and `null` leaves each harness on its own default.
  options.agentRuntime.servers = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
  };

  config = {
    perSystem = {pkgs, ...}: let
      system = pkgs.stdenv.hostPlatform.system;
    in {
      packages.mcp-servers = pkgs.symlinkJoin {
        name = "mcp-servers";
        paths = map (s: (s.from or inputs.self).packages.${system}.${s.command}) (lib.attrValues local);
      };
    };

    flake.nixosModules.tools = {
      config,
      pkgs,
      ...
    }: let
      system = pkgs.stdenv.hostPlatform.system;
      inherit (config.agentRuntime) toolsets;
    in {
      # A toolset is what a session opts into beyond `base`, which every session
      # has: MCP servers, packages on PATH and device nodes in the sandbox.
      # Harness modules turn `agentRuntime.servers` into their own config
      # spelling.
      options.agentRuntime = {
        servers = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          readOnly = true;
        };

        toolsets = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              glyph = lib.mkOption {type = lib.types.str;};
              color = lib.mkOption {type = lib.types.str;};
              label = lib.mkOption {type = lib.types.str;};
              servers = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
              };
              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [];
              };
              devices = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
              };
            };
          });
        };
      };

      config = {
        # A bearer becomes the path of its secret here, so a renamed secret is a
        # build error rather than a server that fails to authenticate.
        agentRuntime.servers =
          lib.mapAttrs (
            _: s: s // lib.optionalAttrs (s ? bearer) {bearer = config.sops.secrets.${s.bearer}.path;}
          )
          servers;

        sops.secrets = lib.mapAttrs' (_: s: lib.nameValuePair s.bearer {owner = "luc";}) bearers;

        # A server is also a toolset of its own in the picker, so the two share
        # one namespace.
        assertions =
          [
            {
              assertion = toolsets ? base;
              message = "agentRuntime.toolsets needs a `base` toolset";
            }
            {
              assertion = lib.intersectAttrs toolsets servers == {};
              message = "agentRuntime.toolsets names collide with servers: ${toString (lib.attrNames (lib.intersectAttrs toolsets servers))}";
            }
          ]
          ++ lib.mapAttrsToList (name: t: {
            assertion = lib.all (s: servers ? ${s}) t.servers;
            message = "agentRuntime.toolsets.${name} names an unknown server";
          })
          toolsets;

        environment.systemPackages = [
          inputs.self.packages.${system}.mcp-servers
          # Support packages, not servers.
          inputs.self.packages.${system}.playwright-mcp-icon
          inputs.self.packages.${system}.playwright-mcp-desktop
          pkgs.playwright-driver
        ];
      };
    };
  };
}
