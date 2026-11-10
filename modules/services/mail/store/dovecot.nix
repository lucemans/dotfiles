{
  config,
  pkgs,
  ...
}: let
  mail = import ../topology.nix;
  secrets = config.sops.secrets;
  certs = config.security.acme.certs.${mail.name}.directory;

  junk = pkgs.writeText "junk.sieve" ''
    require ["fileinto"];
    if header :is "X-Spam" "Yes" {
      fileinto "Junk";
      stop;
    }
  '';
in {
  environment.systemPackages = [pkgs.dovecot_pigeonhole];

  services.dovecot2 = {
    enable = true;
    settings = {
      dovecot_config_version = "2.4.5";
      dovecot_storage_version = "2.4.5";
      protocols = {
        imap = true;
        lmtp = true;
      };

      mail_driver = "maildir";
      mail_home = "${mail.vmail}/%{user | domain}/%{user | username}";
      mail_path = "~/Maildir";
      mailbox_list_storage_escape_char = ''"\\"'';
      mail_uid = "vmail";
      mail_gid = "vmail";
      recipient_delimiter = "+";

      ssl = "required";
      ssl_server_cert_file = "${certs}/fullchain.pem";
      ssl_server_key_file = "${certs}/key.pem";

      "passdb passwd-file".passwd_file_path = secrets.mail_passwd.path;
      "userdb passwd-file".passwd_file_path = secrets.mail_passwd.path;

      "namespace inbox" = {
        inbox = true;
        separator = "/";
        "mailbox Drafts" = {
          special_use = "\\Drafts";
          auto = "subscribe";
        };
        "mailbox Sent" = {
          special_use = "\\Sent";
          auto = "subscribe";
        };
        "mailbox Junk" = {
          special_use = "\\Junk";
          auto = "subscribe";
        };
        "mailbox Trash" = {
          special_use = "\\Trash";
          auto = "subscribe";
        };
        "mailbox Archive" = {
          special_use = "\\Archive";
          auto = "subscribe";
        };
      };

      "protocol lmtp".mail_plugins.sieve = true;
      "sieve_script junk" = {
        type = "before";
        path = junk;
      };

      service = [
        {
          _section.name = "imap-login";
          "inet_listener imap".port = 0;
          "inet_listener imaps" = {
            port = 993;
            ssl = true;
          };
        }
        {
          _section.name = "lmtp";
          "unix_listener /var/lib/postfix/queue/private/dovecot-lmtp" = {
            user = config.services.postfix.user;
            group = config.services.postfix.group;
            mode = "0600";
          };
        }
        {
          _section.name = "auth";
          "unix_listener /var/lib/postfix/queue/private/auth" = {
            user = config.services.postfix.user;
            group = config.services.postfix.group;
            mode = "0600";
          };
        }
      ];
    };
  };

  systemd.services.dovecot = {
    after = ["postfix-setup.service" "acme-${mail.name}.service"];
    wants = ["postfix-setup.service" "acme-${mail.name}.service"];
  };
}
