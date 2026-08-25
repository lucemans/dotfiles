{...}: {
  flake.nixosModules.teapot = {
    self,
    config,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.teapotInference
      self.nixosModules.litellm
      self.nixosModules.searxng
      self.nixosModules.attic
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
      templates = {
        cargo-credentials = {
          content = ''
            [hello]
            test = "${config.sops.placeholder.teapot_github_pat}"
          '';
          path = "/home/luc/testing.toml";
          mode = "0600";
        };
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
