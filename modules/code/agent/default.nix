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
    inherit (import ../../network/services.nix) services;
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
    pi = config.agentRuntime.pi;
    omp = config.agentRuntime.omp;

    ompProfile = profile: let
      inherit (profile) role;
    in
      {
        label = role;
        tool =
          if role == "gpt"
          then "omp"
          else "omp-${role}";
        # A profile with a catalog leaves --model to the picked entry.
        command =
          ["omp" "--config" "${omp.settings}" "--config" "${omp.roles.${role}}" "--model"]
          ++ lib.optional (!(profile ? catalog)) "@default";
        inherit (profile) glyph color blurb logo;
      }
      // lib.optionalAttrs (profile ? catalog) {inherit (profile) catalog;};

    # The menu tree, the accepted tool names, the usage line, the launch
    # dispatch, and what the picker shows all come from here, so a harness is
    # added in one place. Kitty gets the logo inline; every other terminal
    # falls back to the glyph in its truecolor triplet.
    harnesses = [
      {
        label = "omp";
        glyph = "󰚩";
        color = "189;147;249";
        blurb = "Oh My Pi";
        logo = ./icons/omp.png;
        profiles = map ompProfile [
          {
            role = "gpt";
            glyph = "";
            color = "16;163;127";
            blurb = "OpenAI";
            logo = ./icons/openai.png;
          }
          {
            role = "claude";
            glyph = "󰦣";
            color = "217;119;87";
            blurb = "Anthropic";
            logo = ./icons/claude.png;
          }
          {
            role = "kimi";
            glyph = "";
            color = "248;248;242";
            blurb = "Moonshot";
            logo = ./icons/kimi.png;
          }
          {
            role = "local";
            glyph = "";
            color = "80;250;123";
            blurb = "v3x-inference";
            logo = ./icons/local.png;
          }
          {
            role = "openrouter";
            glyph = "";
            color = "148;163;184";
            blurb = "OpenRouter";
            logo = ./icons/openrouter.png;
            # LiteLLM is the authority, not OpenRouter's public catalog: a
            # model absent from the proxy cannot be routed, so it must not be
            # offered. Wildcard routes are expanded into concrete ids.
            catalog = {
              url = "https://${services.inference.name}/v1/models?return_wildcard_routes=true";
              token = config.sops.secrets.v3x_inference_token.path;
              prefix = "openrouter/";
              qualify = "v3x-inference/";
            };
          }
        ];
      }
      {
        label = "claude-code";
        glyph = "";
        color = "217;119;87";
        blurb = "Claude Code";
        logo = ./icons/claude.png;
        profiles = [
          {
            label = "claude";
            tool = "claude";
            command = ["claude"];
            glyph = "󰦣";
            color = "217;119;87";
            blurb = "Anthropic";
            logo = ./icons/claude.png;
          }
          {
            label = "gpt";
            tool = "claude-gpt";
            command = [
              "claude"
              "--model"
              "gpt-6-sol"
              "--settings"
              ''{"availableModels":["gpt-6-sol"],"enforceAvailableModels":true}''
            ];
            glyph = "";
            color = "16;163;127";
            blurb = "gpt-6-sol";
            logo = ./icons/openai.png;
          }
        ];
      }
      {
        label = "opencode";
        tool = "opencode";
        command = ["opencode"];
        glyph = "";
        color = "248;248;242";
        blurb = "OpenCode";
        logo = ./icons/opencode.png;
      }
      {
        label = "pi";
        tool = "pi";
        command = ["pi"];
        glyph = "π";
        color = "139;233;253";
        blurb = "pi";
        logo = ./icons/pi.png;
      }
      {
        label = "bash";
        tool = "bash";
        command = ["bash" "--norc"];
        glyph = "";
        color = "78;170;37";
        blurb = "sandbox shell";
        logo = ./icons/gnubash.png;
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
