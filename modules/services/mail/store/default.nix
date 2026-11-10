_: let
  inherit (import ../../../network/topology.nix) acmeEmail;
  inherit (import ../../../network/hosts.nix) hosts;
  mail = import ../topology.nix;
in {
  flake.nixosModules.mailStore = {config, ...}: let
    secrets = config.sops.secrets;
    relayAddress = hosts.${mail.relay}.address;

    postfixTable = {
      sopsFile = ../../../../config/mail.sops.yaml;
      group = config.services.postfix.group;
      mode = "0440";
      reloadUnits = ["postfix.service"];
    };

    senderTable =
      postfixTable
      // {
        reloadUnits = [];
        restartUnits = ["postfix-setup.service" "postfix.service"];
      };
  in {
    imports = [
      ./postfix.nix
      ./dovecot.nix
      ./rspamd.nix
    ];

    v3x.backup = {
      paths = ["/var/lib/vmail" "/var/lib/postfix/queue" "/var/lib/redis-rspamd"];
      exclude = ["dovecot.index.cache"];
    };

    sops.secrets = {
      mail_domains = postfixTable;
      mail_mailboxes = senderTable;
      mail_aliases = senderTable;
      mail_passwd = {
        sopsFile = ../../../../config/mail.sops.yaml;
        owner = config.services.dovecot2.settings.default_internal_user;
      };
      mail_dkim = {
        sopsFile = ../../../../config/mail.sops.yaml;
        owner = config.services.rspamd.user;
        restartUnits = ["rspamd.service"];
      };
      acme_cloudflare_token = {};
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = acmeEmail;
      certs.${mail.name} = {
        dnsProvider = "cloudflare";
        extraLegoFlags = ["--dns.propagation.wait=60s"];
        credentialFiles.CF_DNS_API_TOKEN_FILE = secrets.acme_cloudflare_token.path;
        reloadServices = ["postfix.service" "dovecot.service"];
      };
    };

    systemd.tmpfiles.rules = ["d ${mail.vmail} 0700 vmail vmail -"];

    networking.firewall.extraCommands = ''
      iptables -I nixos-fw ! -i lo -p tcp --dport 25 -j nixos-fw-refuse
      iptables -I nixos-fw -i wg0 -s ${relayAddress} -p tcp --dport 25 -j nixos-fw-accept
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D nixos-fw -i wg0 -s ${relayAddress} -p tcp --dport 25 -j nixos-fw-accept 2>/dev/null || true
      iptables -D nixos-fw ! -i lo -p tcp --dport 25 -j nixos-fw-refuse 2>/dev/null || true
    '';
  };
}
