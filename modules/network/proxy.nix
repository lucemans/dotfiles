{...}: let
  inherit (import ./topology.nix) hub zone acmeEmail trusted guests hosts services;
in {
  flake.nixosModules.proxy = {
    config,
    lib,
    ...
  }: let
    isHub = config.networking.hostName == hub;

    hubAddress = hosts.${hub}.address;

    addressesOf = group:
      lib.mapAttrsToList (_: host: host.address)
      (lib.filterAttrs (_: host: host.group or null == group) hosts);

    allowedFrom = svc: [trusted] ++ lib.concatMap addressesOf svc.access;

    assets = ./data;

    vhost = _: svc:
      lib.nameValuePair "https://${svc.name}" {
        useACMEHost = zone;
        extraConfig = ''
          bind ${hubAddress}

          route {
            @denied not remote_ip ${lib.concatStringsSep " " (allowedFrom svc)}
            respond @denied 403

            reverse_proxy ${svc.upstream}
          }

          handle_errors {
            root * ${assets}
            rewrite * /error.html
            file_server
          }
        '';
      };

    guestFacing = lib.filterAttrs (_: svc: svc.access != []) services;
  in {
    sops.secrets.acme_cloudflare_token = lib.mkIf isHub {};

    security.acme = lib.mkIf isHub {
      acceptTerms = true;
      defaults.email = acmeEmail;

      certs.${zone} = {
        domain = "*.${zone}";
        extraDomainNames = [zone];
        dnsProvider = "cloudflare";
        extraLegoFlags = ["--dns.propagation-wait=60s"];
        credentialFiles.CF_DNS_API_TOKEN_FILE =
          config.sops.secrets.acme_cloudflare_token.path;
        group = "caddy";
      };
    };

    services.caddy = lib.mkIf isHub {
      enable = true;
      virtualHosts =
        lib.mapAttrs' vhost services
        // {
          "https://*.${zone}" = {
            useACMEHost = zone;
            extraConfig = ''
              bind ${hubAddress}
              root * ${assets}
              rewrite * /404.html
              file_server
            '';
          };
        };
    };

    systemd.services.caddy = lib.mkIf isHub {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };

    networking.firewall.extraCommands = lib.optionalString (isHub && guestFacing != {}) ''
      iptables -N v3x-guest-allow 2>/dev/null || iptables -F v3x-guest-allow
      iptables -A v3x-guest-allow -d ${hubAddress} -p tcp -m multiport --dports 80,443 -j ACCEPT
    '';

    networking.firewall.extraStopCommands = lib.optionalString (isHub && guestFacing != {}) ''
      iptables -F v3x-guest-allow 2>/dev/null || true
    '';
  };
}
