{...}: {
  imports = [
    ./playwright.nix
    ./repo-reader.nix
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
      };
    };

    nixosModules.mcp = {
      self,
      pkgs,
      ...
    }: {
      environment.systemPackages = [
        self.packages.${pkgs.system}.playwright-mcp
        self.packages.${pkgs.system}.playwright-mcp-icon
        self.packages.${pkgs.system}.playwright-mcp-desktop
        self.packages.${pkgs.system}.repo-reader-mcp
        pkgs.playwright-driver
      ];
    };
  };
}
