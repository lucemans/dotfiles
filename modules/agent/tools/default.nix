{inputs, ...}: {
  imports = [
    ./options.nix
    ./playwright/default.nix
    ./repo-reader/default.nix
    ./github-reader/default.nix
    ./nixos/default.nix
  ];

  agentRuntime.servers = {
    playwright = {
      command = "playwright-mcp";
      blurb = "browser automation";
      # A browser launch outruns the shared timeout.
      timeout = null;
    };
    dapp_wallet = {
      command = "dapp-wallet-mcp";
      blurb = "test wallet in the playwright browser";
    };
    repo_reader = {
      command = "repo-reader-mcp";
      blurb = "read public repositories";
    };
    github_reader = {
      command = "github-reader-mcp";
      blurb = "read-only GitHub pull requests, issues, and CI";
      # A job log downloads from blob storage after the API call, which can
      # outrun the shared timeout.
      timeout = 90000;
    };
    eth_data = {
      command = "eth-data-mcp";
      from = inputs.eth-data;
      blurb = "Ethereum chain data";
    };
    nixos = {
      command = "mcp-nixos-sandbox";
      blurb = "nixpkgs and NixOS options";
    };
    plan_env = {
      command = "plan-env-md-mcp";
      from = inputs.plan-env-md;
      blurb = "plan.env.md documents";
    };
    error_menu = {
      url = "https://error.menu/mcp";
      bearer = "v3x_error_menu_token";
      blurb = "error.menu projects and jobs";
    };
    sdrangel = {
      # Served by the SDRangel window on the host, so it connects only while
      # SDRangel runs.
      url = "http://127.0.0.1:8092";
      blurb = "SDRangel on the host";
    };
  };

  flake.nixosModules.tools = {pkgs, ...}: {
    agentRuntime.toolsets = {
      base = {
        label = "Base";
        glyph = "";
        color = "248;248;242";
        servers = ["repo_reader" "github_reader" "nixos" "plan_env" "playwright" "error_menu"];
      };
      rf = {
        label = "Radio Frequency";
        glyph = "";
        color = "255;184;108";
        servers = ["sdrangel"];
        packages = [pkgs.hackrf];
        # HackRF uses libusb's usbfs backend. The device bus directory stays
        # live across reconnects; sysfs is only an optional enumeration path.
        devices = ["/dev/bus/usb"];
      };
      ethereum = {
        label = "Ethereum";
        glyph = "";
        color = "98;126;234";
        servers = ["dapp_wallet" "eth_data"];
      };
      manufacturing = {
        label = "Manufacturing";
        glyph = "";
        color = "80;250;123";
        # Render and inspect parts from code; the 3D modeling MCPs join here.
        packages = [pkgs.openscad-unstable pkgs.f3d];
      };
      kettle-dev = {
        label = "Kettle dev";
        glyph = "⇄";
        color = "189;147;249";
        # Kettle Runner gives each run its own network namespace through pasta,
        # which opens /dev/net/tun; nftables and dnsmasq run inside that namespace.
        packages = [pkgs.passt pkgs.nftables pkgs.dnsmasq pkgs.bubblewrap];
        devices = ["/dev/net/tun"];
      };
    };
  };
}
