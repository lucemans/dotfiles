{...}: {
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
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
    pi = config.agentRuntime.pi;
    omp = config.agentRuntime.omp;

    ompProfile = role: {
      label = role;
      tool =
        if role == "gpt"
        then "omp"
        else "omp-${role}";
      command = ["omp" "--config" "${omp.settings}" "--config" "${omp.roles.${role}}" "--model" "@default"];
    };

    # The menu tree, the accepted tool names, the usage line, and the launch
    # dispatch all come from here, so a harness is added in one place.
    harnesses = [
      {
        label = "omp";
        profiles = map ompProfile ["gpt" "claude" "kimi" "local"];
      }
      {
        label = "claude-code";
        profiles = [
          {
            label = "claude";
            tool = "claude";
            command = ["claude"];
          }
          {
            label = "gpt";
            tool = "claude-gpt";
            command = [
              "claude"
              "--model"
              "gpt-5.6-terra"
              "--settings"
              ''{"availableModels":["gpt-5.6-terra"],"enforceAvailableModels":true}''
            ];
          }
        ];
      }
      {
        label = "opencode";
        tool = "opencode";
        command = ["opencode"];
      }
      {
        label = "pi";
        tool = "pi";
        command = ["pi"];
      }
      {
        label = "bash";
        tool = "bash";
        command = ["bash" "--norc"];
      }
    ];

    envFile = config.sops.templates.agent-env.path;

    agent = import ./runtime.nix {
      inherit pkgs lib selfpkgs pi omp envFile;
      targets = lib.concatMap (harness: harness.profiles or [harness]) harnesses;
      picker = import ./picker.nix {inherit lib harnesses;};

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
  in {
    options.agentRuntime = {
      pi = {
        package = lib.mkOption {type = lib.types.package;};
        models = lib.mkOption {type = lib.types.package;};
        settings = lib.mkOption {type = lib.types.package;};
      };
      omp = {
        package = lib.mkOption {type = lib.types.package;};
        models = lib.mkOption {type = lib.types.package;};
        settings = lib.mkOption {type = lib.types.package;};
        mcp = lib.mkOption {type = lib.types.package;};
        roles = lib.mkOption {type = lib.types.attrsOf lib.types.package;};
      };
    };

    config = {
      sops.templates.agent-env = {
        owner = "luc";
        content = ''
          ANTHROPIC_AUTH_TOKEN="${config.sops.placeholder.v3x_agent_token}"
          ANTHROPIC_API_KEY="${config.sops.placeholder.v3x_agent_token}"
        '';
      };

      home-manager.users.luc.home.packages = [agent];
    };
  };
}
