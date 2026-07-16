{...}: {
  perSystem = {pkgs, ...}: {
    packages.mcp-nixos-sandbox = pkgs.writeShellApplication {
      name = "mcp-nixos-sandbox";
      runtimeInputs = [pkgs.bubblewrap];
      text = ''
        exec bwrap \
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
          --dir /home \
          --dir /home/sandbox \
          --setenv HOME /home/sandbox \
          --setenv XDG_CACHE_HOME /tmp/cache \
          --setenv XDG_CONFIG_HOME /tmp/config \
          --setenv XDG_DATA_HOME /tmp/data \
          --setenv PATH ${pkgs.mcp-nixos}/bin \
          --setenv SSL_CERT_FILE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
          --chdir /home/sandbox \
          -- ${pkgs.mcp-nixos}/bin/mcp-nixos
      '';
    };
  };
}
