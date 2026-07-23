{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.peripheral = {
    config,
    pkgs,
    ...
  }: let
    nixosConfig = config;
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    imports = [
      # self.nixosModules.plasma
      self.nixosModules.environment
      self.nixosModules.nix
    ];

    users.users.luc = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../secrets/ssh.key
      ];
      packages = with pkgs; [
        tree
        fastfetch
        micro
        git
        lnav
        jq
        tmux
      ];
    };

    security.sudo.wheelNeedsPassword = false;
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
      2022 # SSH
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    services.fstrim.enable = true;

    environment.systemPackages = with pkgs; [
    ];
  };
}
