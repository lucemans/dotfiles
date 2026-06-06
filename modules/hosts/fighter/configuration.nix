{ self, inputs, ... }:
{
  flake.nixosModules.fighter =
    { self, pkgs, lib, ... }:
    {
      networking.hostName = "v3x-fighter";
      networking.networkmanager.enable = true;

      time.timeZone = "Europe/Amsterdam";
      i18n.defaultLocale = "en_US.UTF-8";

      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      users.users.luc = {
        isNormalUser = true;
        initialPassword = "12345";
        extraGroups = [ "wheel" ];
        packages = with pkgs; [
          tree
        ];
      };

      environment.systemPackages = with pkgs; [
        vim
      ];

      services.openssh.enable = true;

      system.stateVersion = "26.05";
    };
}
