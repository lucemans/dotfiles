{
  flake.nixosModules.claude-code = {
    self,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      claude-code
    ];

    # Claude Code does not read ~/.claude/mcp.json; the declarative system-wide
    # location is /etc/claude-code/managed-mcp.json. Deploying it gives Nix
    # exclusive control over MCP servers: `claude mcp add` is rejected and
    # claude.ai connectors are suppressed unless re-allowed in managed settings.
    environment.etc."claude-code/managed-mcp.json".text = builtins.toJSON {
      mcpServers = self.mcp.claude;
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
    };
  };
}
