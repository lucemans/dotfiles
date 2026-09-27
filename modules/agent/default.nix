{inputs, ...}: {
  imports = [
    ./harnesses
    ./tools
    ./tripwire.nix
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

    # The picker lists base first, then the other toolsets, then each server
    # outside base as a toolset of its own, so one can be added on its own. A
    # toolset row lists what it adds; a server row keeps its own blurb.
    toolsetChoice = name: t:
      t
      // {
        inherit name;
        blurb = lib.concatStringsSep ", " (t.servers ++ map lib.getName t.packages ++ t.devices);
      };
    choices =
      [(toolsetChoice "base" toolsets.base)]
      ++ lib.mapAttrsToList toolsetChoice (removeAttrs toolsets ["base"])
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
    # One worktree directory per repository, named after its primary checkout,
    # so the picker creates worktrees where the sandbox mounts them.
    worktreeBase = ''$HOME/dev/wt/$(basename "$primary")-$(printf '%s' "$primary" | sha256sum | cut -c1-7)'';

    sandbox = import ./runtime.nix {
      inherit pkgs lib envFile harnesses worktreeBase;
      toolsets = choices;
      selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # Taken from sops rather than written out, so a renamed secret is a build
      # error here instead of a bubblewrap failure at launch.
      secretPaths = [
        # opencode resolves this one itself, through a {file:} reference.
        config.sops.secrets.v3x_inference_token.path
        # Every harness reads this one itself: omp and Claude through a
        # command, OpenCode through a {file:} reference.
        config.sops.secrets.v3x_error_menu_token.path
        envFile
      ];
    };

    agent = import ./picker.nix {
      inherit pkgs sandbox worktreeBase;
      toolsets = choices;
      # The picker lists harnesses in this order.
      harnesses = map (name: harnesses.${name} // {inherit name;}) ["omp" "claude" "opencode" "pi" "bash"];
    };

    # Herdr resumes an OMP pane by typing `omp --resume=<session>` into a fresh
    # host shell. OMP exists only inside the sandbox, so this name hands the
    # command to `agent omp`, which recovers the session's profile.
    ompEntry = pkgs.writeShellScriptBin "omp" ''
      exec ${agent}/bin/agent omp "$@"
    '';
  in {
    # A harness module declares what the picker shows (glyph, color, blurb,
    # logo) and either a `command` or `profiles` of such entries. The sandbox
    # puts its `package` on PATH and mounts the config files it names. A harness
    # with `mcp` gets a file at `path` (under $HOME unless absolute) that holds
    # the chosen toolsets' entries of `servers` under `key`.
    options.agentRuntime.harnesses = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
    };

    config = {
      agentRuntime.harnesses.bash = {
        command = ["bash" "--norc"];
        glyph = "";
        color = "78;170;37";
        blurb = "sandbox shell";
        logo = ./icons/gnubash.png;
      };

      sops.templates.agent-env = {
        owner = "luc";
        content = ''
          ANTHROPIC_AUTH_TOKEN="${config.sops.placeholder.v3x_agent_token}"
          ANTHROPIC_API_KEY="${config.sops.placeholder.v3x_agent_token}"
        '';
      };

      users.users.luc.packages = [agent ompEntry];
    };
  };
}
