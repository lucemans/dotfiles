{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../network/hosts.nix) hosts;
  mail = import ../topology.nix;
  secrets = config.sops.secrets;
  relayAddress = hosts.${mail.relay}.address;
  dkimKeys = "/run/rspamd/dkim";

  relayMap = pkgs.writeText "external-relay.map" ''
    ${relayAddress}
    127.0.0.1
    ::1
  '';

  writeDkimKeys = pkgs.writeShellApplication {
    name = "rspamd-dkim-keys";
    runtimeInputs = [pkgs.jq];
    text = ''
      install -d -m 0700 ${dkimKeys}
      jq -r 'keys[]' ${secrets.mail_dkim.path} | while read -r domain; do
        case "$domain" in
          "" | */* | .*) echo "rspamd-dkim-keys: bad domain '$domain'" >&2; exit 1 ;;
        esac
        jq -r --arg domain "$domain" '.[$domain]' ${secrets.mail_dkim.path} > "${dkimKeys}/$domain.dkim.key"
      done
    '';
  };

  fromMatchesEnvelope = pkgs.writeText "rspamd.local.lua" ''
    rspamd_config:register_symbol({
      name = 'AUTH_FROM_NOT_ENVELOPE',
      type = 'prefilter',
      callback = function(task)
        if not task:get_user() then return end
        local envelope = task:get_from('smtp')
        local header = task:get_from('mime')
        local sender = envelope and envelope[1] and envelope[1].addr
        if not sender or sender == "" or not header or #header ~= 1
            or header[1].addr:lower() ~= sender:lower() then
          task:set_pre_result('reject',
            'From header must match the envelope sender', 'auth_from')
        end
      end,
    })
  '';
in {
  services.redis.servers.rspamd.enable = true;
  users.users.${config.services.rspamd.user}.extraGroups = [config.services.redis.servers.rspamd.group];

  services.rspamd = {
    enable = true;
    postfix.enable = true;
    localLuaRules = fromMatchesEnvelope;
    locals = {
      "redis.conf".text = ''
        servers = "${config.services.redis.servers.rspamd.unixSocket}";
      '';
      # Inbound mail was accepted by the relay already, so a reject here would make the relay bounce to a sender that is often forged.
      "actions.conf".text = ''
        reject = null;
        greylist = null;
      '';
      # The greylist module forces a soft reject on its own; behind the relay it only delays mail, since the client is always the relay.
      "greylist.conf".text = ''
        enabled = false;
      '';
      "external_relay.conf".text = ''
        enabled = true;
        rules {
          EXTERNAL_RELAY_MX {
            strategy = "ip_map";
            ip_map = "${relayMap}";
          }
        }
      '';
      "dkim_signing.conf".text = ''
        path = "${dkimKeys}/$domain.$selector.key";
        selector = "dkim";
        # Aliases in other domains are signed too; the sender login map
        # and AUTH_FROM_NOT_ENVELOPE decide who may use which sender.
        allow_username_mismatch = true;
        use_esld = false;
        # Only mail from an authenticated login is signed, not mail from a
        # local process.
        sign_local = false;
      '';
      "milter_headers.conf".text = ''
        extended_spam_headers = true;
        use = ["authentication-results"];
      '';
    };
    workers.controller.enable = false;
  };

  systemd.services.rspamd.serviceConfig.ExecStartPre = [(lib.getExe writeDkimKeys)];
}
