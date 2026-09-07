{...}: let
  inherit (import ../topology.nix) hub zone acmeEmail trusted containers;
  inherit (import ../hosts.nix) hosts;
  inherit (import ../services.nix) services sections;
in {
  flake.nixosModules.proxy = {
    config,
    lib,
    pkgs,
    ...
  }: let
    isHub = config.networking.hostName == hub;

    hubAddress = hosts.${hub}.address;

    addressesOf = group:
      lib.mapAttrsToList (_: host: host.address)
      (lib.filterAttrs (_: host: host.group or null == group) hosts);

    allowedFrom = svc: [trusted containers] ++ lib.concatMap addressesOf svc.access;

    assets = ../data;

    # The trusted subnet reaches every service, so it is an audience without
    # being a group.
    audiences =
      ["trusted"]
      ++ lib.unique (lib.filter (g: g != null)
        (lib.mapAttrsToList (_: host: host.group or null) hosts));

    sourcesOf = audience:
      if audience == "trusted"
      then [trusted]
      else addressesOf audience;

    visibleTo = audience:
      lib.filterAttrs
      (_: svc: audience == "trusted" || lib.elem audience svc.access)
      services;

    placed = lib.concatMap (section: section.services) sections;

    trailing = lib.filter (key: !lib.elem key placed) (lib.attrNames services);

    laidOut = sections ++ lib.optional (trailing != []) {services = trailing;};

    sectionsFor = audience: let
      visible = visibleTo audience;
    in
      lib.filter (section: section.services != [])
      (map (section: {
          title = section.title or null;
          services =
            map (key: visible.${key})
            (lib.filter (key: visible ? ${key}) section.services);
        })
        laidOut);

    home = pkgs.linkFarm "v3x-home" ([
        {
          name = "icons";
          path = ./icons;
        }
      ]
      ++ map (audience: {
        name = "${audience}.html";
        path = pkgs.writeText "${audience}.html" (import ./home.nix {
          inherit zone;
          sections = sectionsFor audience;
        });
      })
      audiences);

    # Only "/" is rewritten, so that /icons/* still reaches the file server.
    audienceRoute = audience: ''
      @${audience} remote_ip ${lib.concatStringsSep " " (sourcesOf audience)}
      handle @${audience} {
        rewrite / /${audience}.html
        file_server
      }
    '';

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
    assertions = [
      {
        assertion = lib.all (key: services ? ${key}) placed;
        message = "topology sections name services that do not exist: ${
          lib.concatStringsSep ", " (lib.filter (key: !(services ? ${key})) placed)
        }";
      }
    ];

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
          "https://${zone}" = {
            useACMEHost = zone;
            extraConfig = ''
              bind ${hubAddress}
              root * ${home}

              ${lib.concatMapStrings audienceRoute audiences}
              handle {
                respond 403
              }
            '';
          };
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
