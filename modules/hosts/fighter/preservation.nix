{ ... }:
{
  flake.nixosModules.fighterPreservation =
    { lib, ... }:
    {
      boot.initrd.systemd.enable = lib.mkDefault true;

      preservation = {
        enable = true;

        preserveAt."/persistent" = {
          directories = [
            "/etc/nixos"
            {
              directory = "/develop/local";
              user = "luc";
              group = "users";
              mode = "0755";
            }
            {
              directory = "/develop/config";
              user = "luc";
              group = "users";
              mode = "0755";
            }
            "/var/lib/bluetooth"
            {
              directory = "/var/lib/nixos";
              inInitrd = true;
            }
          ];

          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
          ];

          users.luc = {
            directories = [
              ".ssh"
            ];
            files = [ ];
          };
        };
      };
    };
}
