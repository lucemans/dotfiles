{
  perSystem = {pkgs, ...}: {
    packages.claude-code = pkgs.claude-code;
  };

  flake.nixosModules.claude-code = {
    self,
    pkgs,
    ...
  }: let
    rules = import ../_rules;

    # A project's own .claude/settings.local.json is writable by whoever works
    # in the project, and managed settings are the only tier that outranks it.
    # These mirror the prohibitions in AGENTS.md so they cannot be widened from
    # inside a project. Read-only git stays allowed, as the policy intends.
    gitMutations = map (subcommand: "Bash(git ${subcommand}:*)") rules.gitMutations;
  in {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];

    # Keeps the account file inside ~/.claude instead of ~/.claude.json, so
    # the sandbox shares the whole state with one directory bind.
    environment.sessionVariables.CLAUDE_CONFIG_DIR = "/home/luc/.claude";

    # Claude Code does not read ~/.claude/mcp.json; the declarative system-wide
    # location is /etc/claude-code/managed-mcp.json. Deploying it gives Nix
    # exclusive control over MCP servers: `claude mcp add` is rejected and
    # claude.ai connectors are suppressed unless re-allowed in managed settings.
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

    environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
      # Load claude.ai connectors (Calendar, Drive, ...) alongside the managed
      # set, except Gmail. Denying by name and URL since the display name can
      # change on the claude.ai side.
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
              command = "${self.packages.${pkgs.stdenv.hostPlatform.system}.agent-tripwire}/bin/agent-tripwire";
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
