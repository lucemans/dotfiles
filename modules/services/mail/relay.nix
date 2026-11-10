_: let
  inherit (import ../../network/hosts.nix) hosts;
  mail = import ./topology.nix;
in {
  flake.nixosModules.mailRelay = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.postfix;
    secrets = config.sops.secrets;
    storeAddress = hosts.${mail.store}.address;
    tls = "/var/lib/postfix-tls";
    postconf = lib.getExe' cfg.package "postconf";
  in {
    sops.secrets = {
      relay_hostname.restartUnits = ["postfix-setup.service" "postfix.service"];
      mail_domains = {
        inherit (cfg) group;
        mode = "0440";
        reloadUnits = ["postfix.service"];
      };
    };

    services.unbound.enable = true;

    services.postfix = {
      enable = true;
      settings.main = {
        inet_protocols = "ipv4";
        mydestination = [];
        local_transport = "error:5.1.1 local delivery is disabled";
        mynetworks = ["127.0.0.0/8" "[::1]/128" "${storeAddress}/32"];
        message_size_limit = 104857600;
        maximal_queue_lifetime = "10d";
        bounce_queue_lifetime = "10d";

        relay_domains = ["texthash:${secrets.mail_domains.path}"];
        parent_domain_matches_subdomains = [];
        relay_transport = "relay:[${storeAddress}]:25";
        smtpd_helo_required = true;
        disable_vrfy_command = true;
        smtpd_relay_restrictions = ["permit_mynetworks" "reject_unauth_destination"];
        smtpd_recipient_restrictions = [
          "permit_mynetworks"
          "reject_unauth_destination"
          "reject_unverified_recipient"
        ];
        unverified_recipient_reject_code = 550;
        unverified_recipient_reject_reason = "User unknown";

        postscreen_greet_action = "enforce";
        postscreen_dnsbl_action = "enforce";
        postscreen_dnsbl_threshold = 3;
        postscreen_dnsbl_allowlist_threshold = -1;
        postscreen_dnsbl_sites = [
          "zen.spamhaus.org=127.0.0.[2..11]*3"
          "bl.spamcop.net=127.0.0.2*1"
          "list.dnswl.org=127.0.[0..255].[1..3]*-2"
        ];

        smtpd_tls_chain_files = ["${tls}/key.pem" "${tls}/cert.pem"];
        smtp_tls_security_level = "dane";
        smtp_dns_support_level = "dnssec";
      };

      settings.master = {
        smtp_inet = {
          command = lib.mkForce "postscreen";
          maxproc = 1;
        };
        smtpd = {
          type = "pass";
          command = "smtpd";
        };
        dnsblog = {
          command = "dnsblog";
          maxproc = 0;
        };
        tlsproxy = {
          command = "tlsproxy";
          maxproc = 0;
        };
        outbound = {
          name = toString mail.outboundPort;
          type = "inet";
          private = false;
          command = "smtpd";
          args = [
            "-o"
            "smtpd_client_restrictions=permit_mynetworks,reject"
            "-o"
            "cleanup_service_name=outcleanup"
          ];
        };
        outcleanup = {
          private = false;
          maxproc = 0;
          command = "cleanup";
          args = [
            "-o"
            "header_checks=regexp:${pkgs.writeText "outbound-header-checks" ''
              /^Received: from [^[]*\[100\.127\./ IGNORE
            ''}"
          ];
        };
      };
    };

    systemd.services.postfix-setup.script = lib.mkAfter ''
      hostname="$(cat ${secrets.relay_hostname.path})"
      conf=/var/lib/postfix/conf
      cp --remove-destination "$(readlink $conf/main.cf)" $conf/main.cf
      ${postconf} -c $conf -e "myhostname = $hostname"

      if [ ! -e ${tls}/cert.pem ]; then
        install -d -m 0700 ${tls}
        ${lib.getExe pkgs.openssl} req -x509 -noenc -days 3650 \
          -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
          -subj "/CN=$hostname" -addext "subjectAltName=DNS:$hostname" \
          -keyout ${tls}/key.pem -out ${tls}/cert.pem
      fi
    '';

    networking.firewall.allowedTCPPorts = [25];
  };
}
