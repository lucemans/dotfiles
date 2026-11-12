_: let
  stateDir = "/var/lib/music-assistant";
in {
  flake.nixosModules.musicAssistant = _: {
    v3x.backup.paths = [stateDir];

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
    ];

    virtualisation.oci-containers = {
      backend = "docker";

      containers.music-assistant = {
        image = "ghcr.io/music-assistant/server:2.10.9";

        extraOptions = ["--network=host" "--memory=4g"];

        volumes = ["${stateDir}:/data"];
      };
    };

    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -s 10.0.0.0/8 -p tcp --dport 8097 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport 5353 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport 319:320 -j ACCEPT
      iptables -A nixos-fw -s 10.0.0.0/8 -p udp --dport 32768:60999 -j ACCEPT
    '';
  };
}
