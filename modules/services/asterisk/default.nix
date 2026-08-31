{inputs, ...}: {
  flake.nixosModules.asterisk = {config, ...}: let
    public_ip = "TODO";
    asterisk_trunk_number = "";
  in {
    sops.secrets = {
      asterisk_p1_username = {
        owner = "asterisk";
        group = "asterisk";
        restartUnits = ["asterisk.service"];
      };
      asterisk_p1_password = {
        owner = "asterisk";
        group = "asterisk";
        restartUnits = ["asterisk.service"];
      };
      asterisk_p1_number = {
        owner = "asterisk";
        group = "asterisk";
      };
      asterisk_p2_number = {
        owner = "asterisk";
        group = "asterisk";
      };
      sip_trunk_host = {
        owner = "asterisk";
        group = "asterisk";
      };
    };

    services.asterisk = {
      enable = true;
      confFiles = {
        "logger.conf" = ''
          [general]

          [logfiles]
          ; Add debug output to log
          syslog.local0 => notice,warning,error,debug
        '';
      };
    };
  };
}
