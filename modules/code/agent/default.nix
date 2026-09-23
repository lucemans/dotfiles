{inputs, ...}: {
  imports = [
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
    inherit (config.agentRuntime) harnesses;

    sandbox = import ./runtime.nix {
      inherit pkgs lib envFile harnesses;
      selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # Taken from sops rather than written out, so a renamed secret is a build
      # error here instead of a bubblewrap failure at launch.
      secretPaths = [
        # opencode resolves this one itself, through a {file:} reference.
        config.sops.secrets.v3x_inference_token.path
        # omp resolves this one itself, through a !command header value.
        config.sops.secrets.v3x_error_menu_token.path
        envFile
      ];
    };

    agent = import ./picker.nix {
      inherit pkgs sandbox;
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
    # puts its `package` on PATH and mounts the config files it names.
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

      home-manager.users.luc.home.packages = [agent ompEntry];
    };
  };
}
