{
  flake.nixosModules.opencode = {
    lib,
    pkgs,
    ...
  }: let
    chromiumEntry = builtins.head (
      builtins.filter
      (name: lib.hasPrefix "chromium-" name)
      (builtins.attrNames pkgs.playwright-driver.browsers.entries)
    );
    chromiumExecutable = "${pkgs.playwright-driver.browsers}/${chromiumEntry}/chrome-linux64/chrome";
    opencode-playwright-mcp = pkgs.writeShellApplication {
      name = "opencode-playwright-mcp";
      runtimeInputs = [pkgs.playwright-mcp];
      text = ''
        unset PLAYWRIGHT_BROWSERS_PATH
        export PLAYWRIGHT_MCP_BROWSER=chrome
        export PLAYWRIGHT_MCP_EXECUTABLE_PATH=${chromiumExecutable}
        export PLAYWRIGHT_MCP_USER_DATA_DIR=/home/luc/.cache/ms-playwright/opencode-mcp
        export PLAYWRIGHT_MCP_OUTPUT_DIR=/home/luc/.cache/opencode/playwright-mcp
        exec playwright-mcp "$@"
      '';
    };
  in {
    environment.systemPackages = with pkgs; [
      opencode
      opencode-playwright-mcp
      playwright-driver
    ];

    environment.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.file.".config/opencode/opencode.jsonc" = {
      source = ./opencode/opencode.jsonc;
      force = true;
    };

    home-manager.users.luc.home.file.".config/opencode/AGENTS.md" = {
      source = ./opencode/AGENTS.md;
      force = true;
    };

    home-manager.users.luc.home.file.".config/opencode/agents/visual-qa.md" = {
      source = ./opencode/agents/visual-qa.md;
      force = true;
    };
  };
}
