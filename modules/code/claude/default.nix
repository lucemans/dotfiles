{
  perSystem = {pkgs, ...}: {
    packages.claude-code = pkgs.claude-code;
  };

  flake.nixosModules.claude-code = {
    self,
    pkgs,
    ...
  }: let
    inherit (import ../../network/services.nix) services;

    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};

    rules = import ../_rules;

    # A project's own .claude/settings.local.json is writable by whoever works
    # in the project, and managed settings are the only tier that outranks it.
    # These mirror the prohibitions in AGENTS.md so they cannot be widened from
    # inside a project. Read-only git stays allowed, as the policy intends.
    gitMutations = map (subcommand: "Bash(git ${subcommand}:*)") rules.gitMutations;
  in {
    environment.systemPackages = [selfpkgs.claude-code];
    environment.sessionVariables.CLAUDE_CONFIG_DIR = "/home/luc/.claude";

    environment.etc."claude-code/managed-mcp.json".text = builtins.toJSON {
      mcpServers = self.mcp.claude;
    };

    home-manager.users.luc.home.file =
      (rules.mkSkillFiles ".claude/skills")
      // (rules.mkAgentFiles "claude" ".claude/agents")
      // {
        ".claude/CLAUDE.md" = {
          source = rules.policy;
          force = true;
        };
      };

    # The matching token is carried by the agent env file, not by this module.
    sops.secrets.v3x_agent_token.owner = "luc";

    environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
      env.ANTHROPIC_BASE_URL = "https://${services.agent.name}";
      env.CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";

      allowAllClaudeAiMcps = true;
      deniedMcpServers = [
        {serverName = "claude.ai Gmail";}
        {serverUrl = "https://gmailmcp.googleapis.com/*";}
      ];

      # PreToolUse runs ahead of the permission rules below, so the tripwire
      # sees the attempt, counts it, and answers with prose the model can act
      # on. The deny list stays as the backstop for whatever it does not match.
      hooks.PreToolUse = [
        {
          matcher = "Bash|Read|Edit|Write|Glob|Grep|NotebookEdit";
          hooks = [
            {
              type = "command";
              command = "${selfpkgs.agent-tripwire}/bin/agent-tripwire";
            }
          ];
        }
      ];

      permissions.deny =
        gitMutations
        ++ [
          "Bash(sudo:*)"
          "Bash(sops:*)"
          "Bash(gpg:*)"
          "Bash(gpg2:*)"
          "Bash(direnv:*)"
          "Read(//run/secrets/**)"
          "Read(//home/luc/.config/sops/**)"
          "Read(//etc/nixos/secrets/**)"
        ];
    };
  };
}
