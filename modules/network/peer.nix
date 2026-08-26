{...}: let
  inherit (import ./topology.nix) hub hosts resolver subnet;

  hubPeer = hosts.${hub};

  addressOf = name: hosts.${name}.address;
  names = builtins.attrNames hosts;

  takenAddrs = map addressOf names;
  takenLines = map (name: "  ${addressOf name}  ${name}") names;
in {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib;
  in {
    packages.v3x-peer = pkgs.writeShellApplication {
      name = "v3x-peer";
      runtimeInputs = [pkgs.wireguard-tools pkgs.qrencode];
      text = ''
        name="''${1:-}"
        addr="''${2:-}"
        group="''${3:-}"

        if [ -z "$name" ] || [ -z "$addr" ]; then
          {
            echo "usage: v3x-peer <name> <address> [group]"
            echo
            echo "Prints a topology.nix entry, a wg-quick config and a QR code."
            echo "The private key is printed once and never written to disk."
            echo
            echo "addresses already in topology.nix:"
            printf '%s\n' ${lib.escapeShellArgs takenLines}
          } >&2
          exit 64
        fi

        for used in ${lib.escapeShellArgs takenAddrs}; do
          if [ "$used" = "$addr" ]; then
            echo "v3x-peer: $addr is already in topology.nix" >&2
            exit 1
          fi
        done

        key="$(wg genkey)"
        pub="$(printf '%s' "$key" | wg pubkey)"

        conf="$(printf '%s\n' \
          "[Interface]" \
          "PrivateKey = $key" \
          "Address = $addr/32" \
          "DNS = ${resolver}" \
          "" \
          "[Peer]" \
          "PublicKey = ${hubPeer.publicKey}" \
          "Endpoint = ${hubPeer.endpoint}" \
          "AllowedIPs = ${subnet}" \
          "PersistentKeepalive = 25")"

        echo "# add to hosts in modules/network/topology.nix:"
        echo
        echo "    $name = {"
        echo "      publicKey = \"$pub\";"
        echo "      address = \"$addr\";"
        if [ -n "$group" ]; then
          echo "      group = \"$group\";"
        fi
        echo "    };"
        echo
        echo "# wireguard profile:"
        echo
        echo "$conf"
        echo
        printf '%s' "$conf" | qrencode -t ansiutf8
      '';
    };
  };
}
