{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}: {
  flake.nixosModules.point = {
    self,
    pkgs,
    lib,
    ...
  }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-point";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";
    users.users.luc = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      openssh.authorizedKeys.keyFiles = [
        ./ssh.key
      ];
      packages = with pkgs; [
        tree
        micro
        git
        lnav
        jq
        tmux
      ];
    };

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [
      22
      2022
      30303
      9200
      8545
      3000
    ];
    networking.firewall.allowedUDPPorts = [
      30303
      9200
      8545
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    services.fstrim.enable = true;

    system.stateVersion = "26.05";
  };
}
