{
  config,
  pkgs,
  ...
}: {
  sops.secrets = {
    asterisk_ntfy_url = {
      owner = "asterisk";
      group = "asterisk";
    };
    asterisk_ntfy_token = {
      owner = "asterisk";
      group = "asterisk";
    };
    asterisk_ntfy_topic = {
      owner = "asterisk";
      group = "asterisk";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/spool/asterisk/missed 0750 asterisk asterisk 30d"
  ];

  system.build.voicemail = pkgs.writeShellScript "asterisk-notify-missed" ''
    set -eu
    caller="''${1:-unknown}"
    recording="''${2:-}"

    # the secret files carry no trailing newline, so read reports EOF while
    # still assigning the value, which set -e would otherwise treat as fatal
    read -r url < ${config.sops.secrets.asterisk_ntfy_url.path} || :
    read -r token < ${config.sops.secrets.asterisk_ntfy_token.path} || :
    read -r topic < ${config.sops.secrets.asterisk_ntfy_topic.path} || :

    if [ -s "$recording" ]; then
      set -- -H "Title: Voicemail from $caller" \
             -H "Filename: ''${recording##*/}" \
             -T "$recording"
    else
      set -- -H "Title: Missed call from $caller" \
             -d "No message left"
    fi

    # curl reads the token from stdin, so it never appears in argv
    printf '%s\n' "header = \"Authorization: Bearer $token\"" \
      | ${pkgs.curl}/bin/curl -K - -fsS --max-time 30 \
        -H "Tags: telephone_receiver" "$@" "''${url%/}/$topic"
  '';
}
