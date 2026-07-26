{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}: {
  flake.nixosModules.teapot = {
    self,
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.teapotLlm
      self.nixosModules.teapotHermes
    ];

    nixpkgs.overlays = [
      (final: prev: {
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pythonPackages: super: {
              langfuse = super.langfuse.overridePythonAttrs (old: {
                pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["wrapt"];
              });
            })
          ];
      })
    ];

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
        # ssh-public-key = {
        #   path = "/home/luc/.ssh/id_ed25519.pub";
        #   mode = "0644";
        # };
        # ssh-private-key = {
        #   path = "/home/luc/.ssh/id_ed25519";
        #   mode = "0600";
        # };
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
    ];

    system.stateVersion = "26.05";
  };
}
