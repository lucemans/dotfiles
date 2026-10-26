_: {
  flake.nixosModules.teapot = {
    self,
    config,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.wireguard
      self.nixosModules.nodeMetrics
      self.nixosModules.dns
      self.nixosModules.proxy
      self.nixosModules.peripheral
      self.nixosModules.teapotInference
      self.nixosModules.piperSpeech
      self.nixosModules.qwen3Speech
      self.nixosModules.litellm
      self.nixosModules.librechat
      self.nixosModules.searxng
      self.nixosModules.mealie
      self.nixosModules.freshrss
      self.nixosModules.kanidm
      self.nixosModules.garage
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

    nixpkgs.config.allowUnfree = true;
    # The RTX 3080 Ti, Ampere, compute capability 8.6.
    nixpkgs.config.cudaCapabilities = ["8.6"];
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    sops = {
      age.keyFile = "/home/luc/.config/sops/age/keys.txt";
      defaultSopsFile = ../../config/418.sops.yaml;
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
