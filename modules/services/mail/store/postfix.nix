{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../network/hosts.nix) hosts;
  mail = import ../topology.nix;
  secrets = config.sops.secrets;
  certs = config.security.acme.certs.${mail.name}.directory;
  relayAddress = hosts.${mail.relay}.address;

  texthash = secret: ["texthash:${secret.path}"];

  senderLogins = "/run/postfix-sender-logins";

  writeSenderLogins = pkgs.writers.writePython3 "postfix-sender-logins" {} ''
    import sys

    mailboxes_path, aliases_path = sys.argv[1:]

    with open(mailboxes_path) as f:
        mailboxes = {line.split()[0] for line in f if line.strip()}

    aliases = {}
    with open(aliases_path) as f:
        for line in f:
            key, _, targets = line.strip().partition(" ")
            if key:
                aliases[key] = [
                    t.strip() for t in targets.split(",") if t.strip()
                ]


    def owners(address, seen):
        if address in seen:
            return set()
        if address not in aliases:
            return {address} & mailboxes
        found = set()
        for target in aliases[address]:
            if target == address:
                found |= {address} & mailboxes
            else:
                found |= owners(target, seen | {address})
        return found


    for sender in sorted(mailboxes | set(aliases)):
        found = owners(sender, frozenset())
        if found:
            print(sender, ",".join(sorted(found)))
  '';
in {
  services.postfix = {
    enable = true;
    enableSubmissions = true;
    submissionsOptions = {
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "private/auth";
      smtpd_client_restrictions = "permit_sasl_authenticated,reject";
      smtpd_relay_restrictions = "permit_sasl_authenticated,reject";
      smtpd_sender_restrictions = "reject_authenticated_sender_login_mismatch";
      milter_macro_daemon_name = "ORIGINATING";
      cleanup_service_name = "subcleanup";
    };
    settings.master.subcleanup = {
      private = false;
      maxproc = 0;
      command = "cleanup";
      args = [
        "-o"
        "header_checks=regexp:${pkgs.writeText "submission-header-checks" ''
          /^Received:/ IGNORE
        ''}"
      ];
    };
    settings.main = {
      myhostname = mail.name;
      mydestination = ["localhost"];
      mynetworks = [];
      authorized_submit_users = ["root"];
      smtpd_relay_restrictions = ["reject_unauth_destination"];
      relayhost = ["[${relayAddress}]:${toString mail.outboundPort}"];
      recipient_delimiter = "+";
      message_size_limit = 104857600;
      maximal_queue_lifetime = "10d";
      bounce_queue_lifetime = "10d";

      virtual_mailbox_domains = texthash secrets.mail_domains;
      virtual_mailbox_maps = texthash secrets.mail_mailboxes;
      virtual_alias_maps = texthash secrets.mail_aliases;
      virtual_transport = "lmtp:unix:private/dovecot-lmtp";
      smtpd_sender_login_maps = ["texthash:${senderLogins}"];
      transport_maps = ["inline:{null@localhost=discard:}"];

      smtpd_tls_chain_files = ["${certs}/key.pem" "${certs}/fullchain.pem"];

      milter_default_action = "tempfail";
    };
  };

  systemd.services.postfix = {
    after = ["acme-${mail.name}.service"];
    wants = ["acme-${mail.name}.service"];
  };

  systemd.services.postfix-setup.script = lib.mkAfter ''
    (umask 027; ${writeSenderLogins} ${secrets.mail_mailboxes.path} ${secrets.mail_aliases.path} > ${senderLogins}.new)
    chgrp ${config.services.postfix.group} ${senderLogins}.new
    mv ${senderLogins}.new ${senderLogins}
  '';
}
