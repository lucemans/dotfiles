_: {
  flake.nixosModules.ingestarrPackages = _: {
    services.ingestarr.settings.source = [
      {
        key = "claude-code-npm";
        name = "Claude Code";
        kind = "package";
        icon = "claude";
        package = {
          registry = "npm";
          name = "@anthropic-ai/claude-code";
        };
      }
      {
        key = "codex-npm";
        name = "Codex";
        kind = "package";
        package = {
          registry = "npm";
          name = "@openai/codex";
        };
      }
      {
        key = "omp-npm";
        name = "Oh My Pi";
        kind = "package";
        package = {
          registry = "npm";
          name = "@oh-my-pi/pi-coding-agent";
        };
      }
      {
        key = "agent-client-protocol-crates";
        name = "Agent Client Protocol";
        kind = "package";
        package = {
          registry = "crates";
          name = "agent-client-protocol";
        };
      }
    ];
  };
}
