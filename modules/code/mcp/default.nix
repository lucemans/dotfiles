{inputs, ...}: {
  imports = [
    ./playwright/default.nix
    ./repo-reader/default.nix
    ./nixos/default.nix
  ];

  flake = {
    mcp = {
      opencode = {
        playwright = {
          type = "local";
          command = ["playwright-mcp"];
          enabled = false;
        };
        dapp_wallet = {
          type = "local";
          command = ["dapp-wallet-mcp"];
          enabled = false;
          timeout = 30000;
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
          enabled = false;
          timeout = 30000;
        };
        nixos = {
          type = "local";
          command = ["mcp-nixos-sandbox"];
          enabled = true;
          timeout = 30000;
        };
        plan_env = {
          type = "local";
          command = ["plan-env-md-mcp"];
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
        dapp_wallet = {
          type = "stdio";
          command = "dapp-wallet-mcp";
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
        plan_env = {
          type = "stdio";
          command = "plan-env-md-mcp";
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
        self.packages.${pkgs.stdenv.hostPlatform.system}.dapp-wallet-mcp
        self.packages.${pkgs.stdenv.hostPlatform.system}.repo-reader-mcp
        self.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos-sandbox
        inputs.plan-env-md.packages.${pkgs.stdenv.hostPlatform.system}.plan-env-md-mcp
        inputs.eth-data.packages.${pkgs.stdenv.hostPlatform.system}.eth-data-mcp
        pkgs.playwright-driver
      ];
    };
  };
}
