{...}: {
  perSystem = {pkgs, ...}: let
    py = pkgs.python3Packages;
    networks = {
      mainnet = {
        rpcUrl = "https://ethereum.reth.rs/rpc";
        blockscoutUrl = "https://eth.blockscout.com/api/v2";
      };
      sepolia = {
        rpcUrl = "https://ethereum-sepolia-rpc.publicnode.com";
        blockscoutUrl = "https://eth-sepolia.blockscout.com/api/v2";
      };
      hoodi = {
        rpcUrl = "https://ethereum-hoodi-rpc.publicnode.com";
        blockscoutUrl = "https://eth-hoodi.blockscout.com/api/v2";
      };
    };
    ethDataMcpServer = py.buildPythonApplication {
      pname = "eth-data-mcp-server";
      version = "0.1.0";
      format = "other";
      src = ./eth-data-mcp.py;
      dependencies = [py.mcp];
      dontUnpack = true;
      installPhase = ''
        install -Dm755 "$src" "$out/bin/eth-data-mcp-server"
      '';
    };
  in {
    packages.eth-data-mcp = pkgs.writeShellApplication {
      name = "eth-data-mcp";
      runtimeInputs = [pkgs.bubblewrap pkgs.coreutils pkgs.foundry];
      text = ''
        workspace="$(${pkgs.coreutils}/bin/mktemp -d -p "''${XDG_RUNTIME_DIR:-/tmp}" eth-data-mcp.XXXXXX)"
        trap '${pkgs.coreutils}/bin/rm -rf "$workspace"' EXIT

        bwrap \
          --die-with-parent \
          --unshare-all \
          --share-net \
          --new-session \
          --clearenv \
          --dir /nix \
          --ro-bind /nix/store /nix/store \
          --dir /etc \
          --ro-bind /etc/resolv.conf /etc/resolv.conf \
          --proc /proc \
          --dev /dev \
          --tmpfs /tmp \
          --bind "$workspace" /workspace \
          --chdir /workspace \
          --setenv HOME /workspace/home \
          --setenv PATH "${pkgs.foundry}/bin:${pkgs.coreutils}/bin" \
          --setenv SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
          --setenv ETH_DATA_NETWORKS '${builtins.toJSON networks}' \
          -- ${ethDataMcpServer}/bin/eth-data-mcp-server
      '';
    };
  };
}
