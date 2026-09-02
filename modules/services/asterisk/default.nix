{lib, ...}: {
  flake.nixosModules.asterisk = {
    config,
    pkgs,
    ...
  }: let
    moh = pkgs.runCommand "asterisk-moh-opsound" {} ''
      mkdir -p $out
      tar -xzf ${pkgs.fetchurl {
        url = "https://downloads.asterisk.org/pub/telephony/sounds/releases/asterisk-moh-opsound-wav-2.03.tar.gz";
        hash = "sha256-RJ+4ENFlAsMFL+3wL353s2IGrFoUXz2s9Bd4Q6L8tTg=";
      }} -C $out
    '';
  in {
    imports = [
      ./trunk.nix
      ./pjsip.nix
      ./dialplan.nix
      ./voicemail.nix
    ];

    services.asterisk = {
      enable = true;
      confFiles = {
        "modules.conf" = builtins.readFile ./modules.conf;
        "prometheus.conf" = builtins.readFile ./prometheus.conf;
        "rtp.conf" = builtins.readFile ./rtp.conf;
        "logger.conf" = builtins.readFile ./logger.conf;
        "http.conf" = ''
          [general]
          enabled=yes
          bindaddr=${config.v3x.address}
          bindport=8088
        '';
        "musiconhold.conf" = ''
          [default]
          mode=files
          directory=${moh}
          sort=random
        '';
      };
    };

    users.users.asterisk.extraGroups = ["caddy"];
    security.acme.certs."v3x.host".reloadServices = ["asterisk.service"];

    services.fail2ban = {
      enable = true;
      ignoreIP = [
        "127.0.0.1/8"
        "10.0.0.0/24"
        "10.90.0.0/24"
        "100.127.0.0/24"
      ];
      jails.asterisk.settings = {
        enabled = true;
        filter = "asterisk";
        backend = "systemd";
        journalmatch = "_SYSTEMD_UNIT=asterisk.service";
        banaction = "iptables-allports";
        maxretry = 5;
        findtime = 600;
        bantime = 3600;
      };
    };

    networking.firewall.allowedTCPPorts = [5061];

    networking.firewall.extraCommands = let
      sip_sources = [
        "10.0.0.0/24"
        "10.90.0.0/24"
      ];
    in
      lib.concatMapStringsSep "\n" (net: ''
        iptables -A nixos-fw -s ${net} -p udp --dport 5060 -j ACCEPT
        iptables -A nixos-fw -s ${net} -p udp --dport 10000:20000 -j ACCEPT
      '')
      sip_sources;
  };
}
