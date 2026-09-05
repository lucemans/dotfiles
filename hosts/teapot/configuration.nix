{...}: {
  flake.nixosModules.teapot = {
    self,
    config,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.wireguard
      self.nixosModules.dns
      self.nixosModules.proxy
      self.nixosModules.peripheral
      self.nixosModules.teapotInference
      self.nixosModules.litellm
      self.nixosModules.searxng
      self.nixosModules.attic
      self.nixosModules.asterisk
    ];

    programs.git = {
      enable = true;
      config = {
        user.name = "418teapotcat";
        user.email = "418teapotcat@users.noreply.github.com";
      };
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-teapot";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";
    virtualisation.docker.enable = true;

    sops = {
      age.keyFile = "/home/luc/.config/sops/age/keys.txt";
      defaultSopsFile = ../../secrets/418.sops.yaml;
      secrets = {
        teapot_github_pat = {};
      };
    };

    networking.firewall.allowedTCPPorts = [
    ];
    networking.firewall.allowedUDPPorts = [
    ];

    environment.systemPackages = with pkgs; [
      sops
      age
      claude-code
      github-cli
      net-tools
      rtk
    ];

    system.stateVersion = "26.05";
  };
}
