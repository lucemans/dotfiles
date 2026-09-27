{
  inputs,
  lib,
  ...
}: let
  # One definition per server, in no harness's vocabulary. A local server names
  # its `command`, and its package is the one of that name in the `from` flake.
  # A remote server has a `url` instead, and `bearer` names the sops secret
  # that holds its token.
  servers = lib.mapAttrs (_: s: {timeout = 30000;} // s) {
    playwright = {
      command = "playwright-mcp";
      blurb = "browser automation";
      # A browser launch outruns the shared timeout.
      timeout = null;
    };
    dapp_wallet = {
      command = "dapp-wallet-mcp";
      blurb = "test wallet in the playwright browser";
    };
    repo_reader = {
      command = "repo-reader-mcp";
      blurb = "read public repositories";
    };
    eth_data = {
      command = "eth-data-mcp";
      from = inputs.eth-data;
      blurb = "Ethereum chain data";
    };
    nixos = {
      command = "mcp-nixos-sandbox";
      blurb = "nixpkgs and NixOS options";
    };
    plan_env = {
      command = "plan-env-md-mcp";
      from = inputs.plan-env-md;
      blurb = "plan.env.md documents";
    };
    error_menu = {
      url = "https://error.menu/mcp";
      bearer = "v3x_error_menu_token";
      blurb = "error.menu projects and jobs";
    };
    sdrangel = {
      # Served by the SDRangel window on the host, so it connects only while
      # SDRangel runs.
      url = "http://127.0.0.1:8092";
      blurb = "SDRangel on the host";
    };
  };

  local = lib.filterAttrs (_: s: s ? command) servers;
  remote = lib.filterAttrs (_: s: s ? url) servers;
in {
  imports = [
    ./playwright/default.nix
    ./repo-reader/default.nix
    ./nixos/default.nix
  ];

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
    bearers = lib.filterAttrs (_: s: s ? bearer) remote;
  in {
    # A toolset is what a session opts into beyond `base`, which every session
    # has: MCP servers, packages on PATH and device nodes in the sandbox.
    # Harness modules turn `servers` into their own config spelling.
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
            blurb = lib.mkOption {type = lib.types.str;};
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

      agentRuntime.toolsets = {
        base = {
          glyph = "";
          color = "248;248;242";
          blurb = "every session has these";
          servers = ["repo_reader" "nixos" "plan_env" "playwright" "error_menu"];
        };
        rf = {
          glyph = "";
          color = "255;184;108";
          blurb = "SDRangel and the HackRF";
          servers = ["sdrangel"];
          packages = [pkgs.hackrf];
          # HackRF uses libusb's usbfs backend. The device bus directory stays
          # live across reconnects; sysfs is only an optional enumeration path.
          devices = ["/dev/bus/usb"];
        };
        ethereum = {
          glyph = "";
          color = "98;126;234";
          blurb = "dapp wallet and chain data";
          servers = ["dapp_wallet" "eth_data"];
        };
      };

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
}
