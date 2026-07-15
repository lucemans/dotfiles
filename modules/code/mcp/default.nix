{...}: {
  imports = [
    ./playwright/default.nix
    ./repo-reader/default.nix
    ./eth-data/default.nix
  ];

  flake = {
    mcp = {
      opencode = {
        playwright = {
          type = "local";
          command = ["playwright-mcp"];
          enabled = false;
        };
        repo_reader = {
          type = "local";
          command = ["repo-reader-mcp"];
          enabled = true;
          timeout = 30000;
        };
        eth_data = {
          type = "local";
          command = ["eth-data-mcp"];
          enabled = true;
          timeout = 30000;
        };
      };

      claude = {
        playwright = {
          type = "stdio";
          command = "playwright-mcp";
          args = [];
        };
        repo_reader = {
          type = "stdio";
          command = "repo-reader-mcp";
          args = [];
        };
        eth_data = {
          type = "stdio";
          command = "eth-data-mcp";
          args = [];
        };
      };
    };

    nixosModules.mcp = {
      self,
      pkgs,
      ...
    }: {
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.playwright-mcp
        self.packages.${pkgs.stdenv.hostPlatform.system}.playwright-mcp-icon
        self.packages.${pkgs.stdenv.hostPlatform.system}.playwright-mcp-desktop
        self.packages.${pkgs.stdenv.hostPlatform.system}.repo-reader-mcp
        self.packages.${pkgs.stdenv.hostPlatform.system}.eth-data-mcp
        pkgs.playwright-driver
      ];
    };
  };
}
