{inputs, ...}: {
  imports = [
    ./harnesses
    ./runtime
    ./tools
  ];

  flake.nixosModules.agentRuntime = {
    self,
    config,
    lib,
    pkgs,
    ...
  }: let
    envFile = config.sops.templates.agent-env.path;
    inherit (config.agentRuntime) harnesses servers toolsets;

    toolsetChoice = name: t:
      t
      // {
        inherit name;
        blurb = lib.concatStringsSep ", " (t.servers ++ map lib.getName t.packages ++ t.devices);
      };
    choices =
      [(toolsetChoice "base" toolsets.base)]
      ++ lib.mapAttrsToList toolsetChoice (removeAttrs toolsets ["base" "all"])
      ++ [(toolsetChoice "all" toolsets.all // {blurb = "every toolset and server";})]
      ++ lib.mapAttrsToList (name: s: {
        inherit name;
        inherit (s) blurb;
        label = name;
        glyph = "";
        color = "98;114;164";
        servers = [name];
        packages = [];
        devices = [];
      }) (removeAttrs servers toolsets.base.servers);
    worktreeBase = ''$HOME/dev/wt/$(basename "$primary")-$(printf '%s' "$primary" | sha256sum | cut -c1-7)'';

    sandbox = import ./runtime/sandbox.nix {
      inherit pkgs lib envFile harnesses worktreeBase;
      toolsets = choices;
      selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

      secretPaths = [
        config.sops.secrets.v3x_inference_token.path
        config.sops.secrets.v3x_error_menu_token.path
        envFile
      ];
    };

    agent = import ./runtime/picker/default.nix {
      inherit pkgs sandbox worktreeBase;
      toolsets = choices;
      harnesses = map (name: harnesses.${name} // {inherit name;}) ["omp" "claude" "opencode" "pi" "bash"];
    };

    ompEntry = pkgs.writeShellScriptBin "omp" ''
      exec ${agent}/bin/agent omp "$@"
    '';
  in {
    options.agentRuntime.harnesses = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
    };

    config = {
      agentRuntime.harnesses.bash = {
        command = ["bash" "--norc"];
        glyph = "";
        color = "78;170;37";
        blurb = "sandbox shell";
        logo = ../../assets/icons/gnubash.png;
      };

      sops.templates.agent-env = {
        owner = "luc";
        content = ''
          ANTHROPIC_AUTH_TOKEN="${config.sops.placeholder.v3x_agent_token}"
          ANTHROPIC_API_KEY="${config.sops.placeholder.v3x_agent_token}"
          MNEMOPI_EMBEDDING_API_KEY="${config.sops.placeholder.v3x_inference_token}"
          MNEMOPI_EMBEDDING_DIM=768
        '';
      };

      users.users.luc.packages = [agent ompEntry];
    };
  };
}
