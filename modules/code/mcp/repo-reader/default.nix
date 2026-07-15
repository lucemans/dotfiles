{...}: {
  perSystem = {pkgs, ...}: let
    py = pkgs.python3Packages;
    repoReaderMcpServer = py.buildPythonApplication {
      pname = "repo-reader-mcp-server";
      version = "0.1.0";
      format = "other";
      src = ./repo-reader-mcp.py;
      dependencies = [py.mcp];
      dontUnpack = true;
      installPhase = ''
        install -Dm755 "$src" "$out/bin/repo-reader-mcp-server"
      '';
    };
  in {
    packages = {
      repo-reader-mcp-server = repoReaderMcpServer;

      repo-reader-mcp = pkgs.writeShellApplication {
        name = "repo-reader-mcp";
        runtimeInputs = [pkgs.bubblewrap pkgs.coreutils pkgs.ripgrep];
        text = ''
          workspace="$(${pkgs.coreutils}/bin/mktemp -d -p "''${XDG_RUNTIME_DIR:-/tmp}" repo-reader-mcp.XXXXXX)"
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
            --setenv XDG_CACHE_HOME /workspace/cache \
            --setenv PATH "${pkgs.git}/bin:${pkgs.coreutils}/bin:${pkgs.ripgrep}/bin" \
            --setenv GIT_CONFIG_NOSYSTEM 1 \
            --setenv GIT_CONFIG_GLOBAL /dev/null \
            --setenv GIT_TERMINAL_PROMPT 0 \
            --setenv GIT_ALLOW_PROTOCOL https \
            --setenv GIT_SSL_CAINFO ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
            -- ${repoReaderMcpServer}/bin/repo-reader-mcp-server
        '';
      };
    };
  };
}
