{
  inputs,
  lib,
  ...
}: let
  # One definition per server, in neither tool's vocabulary. `from` is the
  # flake the package comes from, and the package is always named after the
  # command, which holds for every server here.
  defaults = {
    args = [];
    enabled = true;
    timeout = 30000;
    from = inputs.self;
  };

  servers = lib.mapAttrs (_: s: defaults // s) {
    playwright = {
      command = "playwright-mcp";
      enabled = false;
      # A browser launch outruns the shared timeout.
      timeout = null;
    };
    dapp_wallet = {
      command = "dapp-wallet-mcp";
      enabled = false;
    };
    repo_reader = {
      command = "repo-reader-mcp";
    };
    eth_data = {
      command = "eth-data-mcp";
      from = inputs.eth-data;
      enabled = false;
    };
    nixos = {
      command = "mcp-nixos-sandbox";
    };
    plan_env = {
      command = "plan-env-md-mcp";
      from = inputs.plan-env-md;
    };
  };

  # The adapters are the only place either tool's spelling appears.
  # `enabled = false` means off by default, toggled on from the OpenCode UI
  # when a task needs it.
  toOpenCode = s:
    {
      type = "local";
      command = [s.command] ++ s.args;
      inherit (s) enabled;
    }
    // lib.optionalAttrs (s.timeout != null) {inherit (s) timeout;};

  # No `enabled` and no `timeout`. Claude has neither, and its deferred tool
  # schemas already keep an unused server out of the context window, which is
  # what the OpenCode toggle is for.
  toClaude = s: {
    type = "stdio";
    inherit (s) command args;
  };
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
      paths = map (s: s.from.packages.${system}.${s.command}) (lib.attrValues servers);
    };
  };

  flake = {
    mcp = {
      opencode = lib.mapAttrs (_: toOpenCode) servers;
      claude = lib.mapAttrs (_: toClaude) servers;
    };

    nixosModules.mcp = {pkgs, ...}: let
      system = pkgs.stdenv.hostPlatform.system;
    in {
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
